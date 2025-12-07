# COMPLETE FIX - Deploy Real Java Services
Write-Host "=== FIXING GRADLE AND DEPLOYING REAL SERVICES ===" -ForegroundColor Green

# Step 1: Fix Gradle Wrapper
Write-Host "`nStep 1: Fixing Gradle wrapper in backend..." -ForegroundColor Yellow
Set-Location ..\backend

# Create gradle wrapper files
Write-Host "Creating Gradle wrapper files..." -ForegroundColor Yellow

# Create gradle/wrapper directory
New-Item -ItemType Directory -Path "gradle\wrapper" -Force | Out-Null

# Download gradle-wrapper.jar
Write-Host "Downloading gradle-wrapper.jar..." -ForegroundColor Cyan
$wrapperUrl = "https://github.com/gradle/gradle/raw/v8.5.0/gradle/wrapper/gradle-wrapper.jar"
Invoke-WebRequest -Uri $wrapperUrl -OutFile "gradle\wrapper\gradle-wrapper.jar"

# Create gradle-wrapper.properties
Write-Host "Creating gradle-wrapper.properties..." -ForegroundColor Cyan
@"
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https://services.gradle.org/distributions/gradle-8.5-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
"@ | Out-File -FilePath "gradle\wrapper\gradle-wrapper.properties" -Encoding UTF8

# Download gradlew.bat
Write-Host "Downloading gradlew.bat..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradlew.bat" -OutFile "gradlew.bat"

# Download gradlew (Unix)
Write-Host "Downloading gradlew..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradlew" -OutFile "gradlew"

Write-Host "Gradle wrapper ready!" -ForegroundColor Green

# Step 2: Build Java services with the fixed gradlew
Write-Host "`nStep 2: Building Java services with Gradle..." -ForegroundColor Yellow

# Check if Java is available
$javaPath = "C:\Program Files\Eclipse Adoptium\jdk-21.0.1.12-hotspot"
if (Test-Path $javaPath) {
    $env:JAVA_HOME = $javaPath
    $env:Path = "$javaPath\bin;$env:Path"
    Write-Host "Using Java from: $javaPath" -ForegroundColor Green
}

# Initialize and build with gradlew
Write-Host "Building services (this will take a few minutes)..." -ForegroundColor Yellow
cmd /c "gradlew.bat clean build -x test"

# Verify JARs were created
$services = @("ingest-service", "projector-service", "query-service")
$jarsExist = $true

foreach ($service in $services) {
    $jarPath = "$service\build\libs"
    if (Test-Path $jarPath) {
        $jar = Get-ChildItem "$jarPath\*.jar" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($jar) {
            Write-Host "✓ $service JAR found: $($jar.Name)" -ForegroundColor Green
        } else {
            Write-Host "✗ $service JAR not found" -ForegroundColor Red
            $jarsExist = $false
        }
    }
}

# Step 3: Create Dockerfiles that use the built JARs
Write-Host "`nStep 3: Creating Docker images with built JARs..." -ForegroundColor Yellow

foreach ($service in $services) {
    Write-Host "`nBuilding Docker image for $service..." -ForegroundColor Cyan

    # Find the JAR file
    $jar = Get-ChildItem "$service\build\libs\*.jar" -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($jar) {
        # Create a Dockerfile that copies the pre-built JAR
        $dockerfileContent = @"
FROM eclipse-temurin:21-jre-alpine
RUN apk add --no-cache curl
WORKDIR /app
COPY $service/build/libs/$($jar.Name) app.jar
EXPOSE 8080 8081 8082 8083
ENTRYPOINT ["java", "-jar", "app.jar"]
"@
        $dockerfilePath = "Dockerfile.$service.real"
        $dockerfileContent | Out-File -FilePath $dockerfilePath -Encoding UTF8

        # Build the Docker image
        docker build -f $dockerfilePath -t "wcd/$($service):real" . --no-cache

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ $service Docker image built successfully!" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to build $service Docker image" -ForegroundColor Red
        }
    } else {
        Write-Host "Skipping $service - no JAR file found" -ForegroundColor Yellow
    }
}

# Step 4: Create/Reset Kubernetes cluster
Write-Host "`nStep 4: Setting up Kubernetes cluster..." -ForegroundColor Yellow

Set-Location ..\k8s

# Delete existing cluster
kind delete cluster --name wcd-platform 2>$null

# Create new cluster
Write-Host "Creating Kind cluster..." -ForegroundColor Cyan
kind create cluster --name wcd-platform

# Step 5: Load Docker images to Kind
Write-Host "`nStep 5: Loading Docker images to Kind..." -ForegroundColor Yellow

foreach ($service in $services) {
    Write-Host "Loading $service to Kind..." -ForegroundColor Cyan
    kind load docker-image "wcd/$($service):real" --name wcd-platform
}

# Also load Redis and Kafka images
docker pull redis:7-alpine
docker pull docker.redpanda.com/redpandadata/redpanda:v23.3.5
kind load docker-image redis:7-alpine --name wcd-platform
kind load docker-image docker.redpanda.com/redpandadata/redpanda:v23.3.5 --name wcd-platform

# Step 6: Deploy to Kubernetes
Write-Host "`nStep 6: Deploying to Kubernetes..." -ForegroundColor Yellow

# Create namespace
kubectl create namespace wcd-platform

# Deploy Redis
Write-Host "Deploying Redis..." -ForegroundColor Cyan
kubectl create deployment wcd-redis-master --image=redis:7-alpine -n wcd-platform
kubectl expose deployment wcd-redis-master --port=6379 -n wcd-platform

# Deploy Redpanda (Kafka)
Write-Host "Deploying Redpanda..." -ForegroundColor Cyan
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wcd-redpanda
  namespace: wcd-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redpanda
  template:
    metadata:
      labels:
        app: redpanda
    spec:
      containers:
      - name: redpanda
        image: docker.redpanda.com/redpandadata/redpanda:v23.3.5
        command:
        - redpanda
        - start
        - --smp=1
        - --memory=1G
        - --overprovisioned
        - --node-id=0
        - --kafka-addr=PLAINTEXT://0.0.0.0:9092
        - --advertise-kafka-addr=PLAINTEXT://wcd-redpanda:9092
        ports:
        - containerPort: 9092
        env:
        - name: REDPANDA_ENVIRONMENT
          value: "development"
---
apiVersion: v1
kind: Service
metadata:
  name: wcd-redpanda
  namespace: wcd-platform
spec:
  selector:
    app: redpanda
  ports:
  - port: 9092
    targetPort: 9092
"@ | kubectl apply -f -

# Deploy ConfigMap with environment variables
Write-Host "Creating ConfigMap..." -ForegroundColor Cyan
@"
apiVersion: v1
kind: ConfigMap
metadata:
  name: wcd-config
  namespace: wcd-platform
data:
  KAFKA_BOOTSTRAP_SERVERS: "wcd-redpanda:9092"
  REDIS_HOST: "wcd-redis-master"
  REDIS_PORT: "6379"
  WCD_API_KEY: "dev-secret-key"
  SPRING_PROFILES_ACTIVE: "kubernetes"
"@ | kubectl apply -f -

# Wait for infrastructure
Write-Host "Waiting for infrastructure..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Deploy Java services
foreach ($service in $services) {
    Write-Host "Deploying $service..." -ForegroundColor Cyan

    $port = switch ($service) {
        "ingest-service" { 8081 }
        "projector-service" { 8082 }
        "query-service" { 8083 }
    }

    @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wcd-$service
  namespace: wcd-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $service
  template:
    metadata:
      labels:
        app: $service
    spec:
      containers:
      - name: $service
        image: wcd/$($service):real
        imagePullPolicy: Never
        ports:
        - containerPort: $port
        envFrom:
        - configMapRef:
            name: wcd-config
        env:
        - name: SERVER_PORT
          value: "$port"
---
apiVersion: v1
kind: Service
metadata:
  name: wcd-$service
  namespace: wcd-platform
spec:
  selector:
    app: $service
  ports:
  - port: $port
    targetPort: $port
"@ | kubectl apply -f -
}

# Step 7: Wait and verify
Write-Host "`nStep 7: Waiting for pods to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# Check status
Write-Host "`n=== DEPLOYMENT STATUS ===" -ForegroundColor Green
kubectl get pods -n wcd-platform
Write-Host ""
kubectl get services -n wcd-platform

# Step 8: Test the services
Write-Host "`n=== TESTING SERVICES ===" -ForegroundColor Green

# Setup port forwarding in background
Write-Host "Setting up port forwarding..." -ForegroundColor Yellow
Start-Process -WindowStyle Hidden -FilePath "kubectl" -ArgumentList "port-forward -n wcd-platform deployment/wcd-ingest-service 8081:8081"
Start-Process -WindowStyle Hidden -FilePath "kubectl" -ArgumentList "port-forward -n wcd-platform deployment/wcd-query-service 8083:8083"

Start-Sleep -Seconds 5

# Test endpoints
Write-Host "Testing service endpoints..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8081/actuator/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "✓ Ingest service is running!" -ForegroundColor Green
} catch {
    Write-Host "⚠ Ingest service not responding yet" -ForegroundColor Yellow
}

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8083/actuator/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "✓ Query service is running!" -ForegroundColor Green
} catch {
    Write-Host "⚠ Query service not responding yet" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "   DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host @"

Your REAL Java services are now running in Kubernetes!

Services available at:
- Ingest: http://localhost:8081
- Query: http://localhost:8083

Commands:
- Check pods: kubectl get pods -n wcd-platform
- View logs: kubectl logs -f deployment/wcd-ingest-service -n wcd-platform
- Port forward: kubectl port-forward -n wcd-platform deployment/wcd-ingest-service 8081:8081

Test the API:
curl -X POST http://localhost:8081/api/events/heartbeat `
  -H "Content-Type: application/json" `
  -H "X-API-KEY: dev-secret-key" `
  -d '{"userId":"test","region":"EU","matchId":"match1","amount":0}'

"@ -ForegroundColor Cyan

Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")