# Fix script for Kind setup issues
Write-Host "=== Fixing Kind Setup Issues ===" -ForegroundColor Green

# 1. Clean up any existing Kind clusters and Docker containers
Write-Host "Step 1: Cleaning up existing resources..." -ForegroundColor Yellow

# Delete any existing Kind clusters
kind delete cluster --name wcd-platform 2>$null
kind delete clusters --all 2>$null

# Stop and remove containers using conflicting ports
docker ps -a | Select-String "kind" | ForEach-Object {
    $id = $_.ToString().Split()[0]
    docker stop $id 2>$null
    docker rm $id 2>$null
}

# Kill processes using our ports
$ports = @(80, 443, 6443, 30000, 30001, 30002)
foreach ($port in $ports) {
    $process = netstat -ano | Select-String ":$port.*LISTENING"
    if ($process) {
        $pid = $process.ToString().Split()[-1]
        Write-Host "Killing process on port $port (PID: $pid)" -ForegroundColor Yellow
        try {
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Host "Could not kill process on port $port" -ForegroundColor Red
        }
    }
}

# 2. Fix Gradle wrapper issue
Write-Host "`nStep 2: Checking Gradle wrapper..." -ForegroundColor Yellow

$backendPath = "..\backend"
$gradlewPath = "$backendPath\gradlew.bat"

if (!(Test-Path $gradlewPath)) {
    Write-Host "Gradle wrapper not found. Creating it..." -ForegroundColor Yellow

    Set-Location $backendPath

    # Check if gradle is installed
    try {
        gradle --version | Out-Null
        Write-Host "Running gradle wrapper task..." -ForegroundColor Green
        gradle wrapper --gradle-version=8.5
    } catch {
        Write-Host "Gradle not installed. Downloading wrapper manually..." -ForegroundColor Yellow

        # Download gradle wrapper files
        $wrapperUrl = "https://raw.githubusercontent.com/gradle/gradle/master/gradle/wrapper/gradle-wrapper.jar"
        $wrapperPropUrl = "https://raw.githubusercontent.com/gradle/gradle/master/gradle/wrapper/gradle-wrapper.properties"

        New-Item -ItemType Directory -Path "gradle\wrapper" -Force
        Invoke-WebRequest -Uri $wrapperUrl -OutFile "gradle\wrapper\gradle-wrapper.jar"

        # Create gradle-wrapper.properties
        @"
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https://services.gradle.org/distributions/gradle-8.5-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
"@ | Out-File -FilePath "gradle\wrapper\gradle-wrapper.properties" -Encoding UTF8

        # Create gradlew.bat
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gradle/gradle/master/gradlew.bat" -OutFile "gradlew.bat"

        # Create gradlew for Linux/Mac
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gradle/gradle/master/gradlew" -OutFile "gradlew"
    }

    Set-Location ..\k8s
}

Write-Host "Gradle wrapper ready!" -ForegroundColor Green

# 3. Build JAR files first
Write-Host "`nStep 3: Building JAR files..." -ForegroundColor Yellow

Set-Location $backendPath

if (Test-Path "gradlew.bat") {
    Write-Host "Building services with Gradle..." -ForegroundColor Green
    .\gradlew.bat clean build -x test

    # Check if JARs were created
    $jars = @(
        "ingest-service\build\libs\ingest-service-*.jar",
        "projector-service\build\libs\projector-service-*.jar",
        "query-service\build\libs\query-service-*.jar"
    )

    foreach ($jar in $jars) {
        if (Test-Path $jar) {
            Write-Host "✓ Found: $jar" -ForegroundColor Green
        } else {
            Write-Host "✗ Missing: $jar" -ForegroundColor Red
        }
    }
}

Set-Location ..\k8s

# 4. Create simplified Kind cluster (single node for now)
Write-Host "`nStep 4: Creating Kind cluster (simplified)..." -ForegroundColor Yellow

# Create a simpler Kind config
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: wcd-platform
nodes:
  - role: control-plane
    extraPortMappings:
    - containerPort: 30000
      hostPort: 30000
      protocol: TCP
    - containerPort: 30001
      hostPort: 30001
      protocol: TCP
    - containerPort: 30002
      hostPort: 30002
      protocol: TCP
"@ | Out-File -FilePath "kind-simple.yaml" -Encoding UTF8

# Create cluster
kind create cluster --config kind-simple.yaml

# Verify cluster
kubectl cluster-info

# 5. Install NGINX Ingress
Write-Host "`nStep 5: Installing Ingress Controller..." -ForegroundColor Yellow
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

Start-Sleep -Seconds 10

# 6. Build Docker images (with pre-built JARs)
Write-Host "`nStep 6: Building Docker images..." -ForegroundColor Yellow

# Update Dockerfiles to copy pre-built JARs instead of building
$services = @("ingest-service", "projector-service", "query-service")

foreach ($service in $services) {
    Write-Host "Building $service..." -ForegroundColor Green

    # Create a simple Dockerfile that copies the JAR
    $dockerfileContent = @"
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY $service/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
"@

    $dockerfileContent | Out-File -FilePath "$backendPath\Dockerfile.$service" -Encoding UTF8

    # Build image
    docker build -f "$backendPath\Dockerfile.$service" -t "ghcr.io/curlyred/individual_semester_6/${service}:latest" $backendPath
}

# 7. Load images to Kind
Write-Host "`nStep 7: Loading images to Kind..." -ForegroundColor Yellow

foreach ($service in $services) {
    Write-Host "Loading $service to Kind..." -ForegroundColor Green
    kind load docker-image "ghcr.io/curlyred/individual_semester_6/${service}:latest" --name wcd-platform
}

# 8. Deploy to Kubernetes
Write-Host "`nStep 8: Deploying to Kubernetes..." -ForegroundColor Yellow

# First create namespace
kubectl create namespace wcd-platform --dry-run=client -o yaml | kubectl apply -f -

# Apply configurations one by one
kubectl apply -f base/namespace/
Start-Sleep -Seconds 2

kubectl apply -f base/configmaps/
kubectl apply -f base/secrets/

# Deploy databases first
kubectl apply -f base/statefulsets/redis.yaml
kubectl apply -f base/statefulsets/redpanda.yaml

Write-Host "Waiting for databases..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# Deploy services
kubectl apply -f base/deployments/

# Check status
kubectl get pods -n wcd-platform

Write-Host "`n=== Fix Complete ===" -ForegroundColor Green
Write-Host "Check pod status with: kubectl get pods -n wcd-platform -w" -ForegroundColor Yellow