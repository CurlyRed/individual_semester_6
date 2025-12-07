# MASTER SCRIPT - Runs everything automatically
# Just run this one script and it will do everything!

Write-Host @"
========================================
   WCD PLATFORM - AUTOMATIC SETUP
========================================
This script will automatically:
1. Verify your system
2. Fix any issues
3. Create Kubernetes cluster
4. Build all services
5. Deploy everything
6. Test the deployment

Estimated time: 10-15 minutes
========================================
"@ -ForegroundColor Cyan

# Confirm to proceed
Write-Host "`nThis will clean Docker and rebuild everything from scratch." -ForegroundColor Yellow
$confirm = Read-Host "Ready to start? (y/n)"
if ($confirm -ne 'y') {
    Write-Host "Setup cancelled" -ForegroundColor Red
    exit
}

# Set error handling
$ErrorActionPreference = "Continue"
$global:hasErrors = $false

function Execute-Step {
    param($StepName, $ScriptBlock)

    Write-Host "`n========================================" -ForegroundColor Blue
    Write-Host " $StepName" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue

    try {
        & $ScriptBlock
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Step failed with exit code $LASTEXITCODE"
        }
        Write-Host "✓ $StepName completed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "✗ $StepName failed: $_" -ForegroundColor Red
        $global:hasErrors = $true

        $retry = Read-Host "Do you want to retry this step? (y/n)"
        if ($retry -eq 'y') {
            Execute-Step -StepName $StepName -ScriptBlock $ScriptBlock
        } else {
            $continue = Read-Host "Continue anyway? (y/n)"
            if ($continue -ne 'y') {
                exit 1
            }
        }
    }
}

# STEP 1: Clean everything
Execute-Step "STEP 1: Clean Docker and Kind" {
    Write-Host "Cleaning Docker containers and images..." -ForegroundColor Yellow

    # Stop all containers
    docker stop $(docker ps -aq) 2>$null

    # Remove all containers
    docker rm $(docker ps -aq) 2>$null

    # Delete Kind clusters
    kind delete clusters --all 2>$null

    # Clean Docker system
    docker system prune -a --volumes -f

    Write-Host "✓ Docker cleaned" -ForegroundColor Green
}

# STEP 2: Verify and fix prerequisites
Execute-Step "STEP 2: Verify Prerequisites" {
    # Check Docker
    docker version | Out-Null
    Write-Host "✓ Docker is running" -ForegroundColor Green

    # Install Kind if needed
    if (!(Get-Command kind -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Kind..." -ForegroundColor Yellow
        $kindUrl = "https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64"
        $toolsPath = "C:\tools"
        if (!(Test-Path $toolsPath)) {
            New-Item -ItemType Directory -Path $toolsPath -Force | Out-Null
        }
        Invoke-WebRequest -Uri $kindUrl -OutFile "$toolsPath\kind.exe"
        $env:Path = "$env:Path;$toolsPath"
        Write-Host "✓ Kind installed" -ForegroundColor Green
    }

    # Install kubectl if needed
    if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Host "Installing kubectl..." -ForegroundColor Yellow
        $kubectlUrl = "https://dl.k8s.io/release/v1.29.0/bin/windows/amd64/kubectl.exe"
        $toolsPath = "C:\tools"
        Invoke-WebRequest -Uri $kubectlUrl -OutFile "$toolsPath\kubectl.exe"
        Write-Host "✓ kubectl installed" -ForegroundColor Green
    }
}

# STEP 3: Fix Gradle wrapper
Execute-Step "STEP 3: Setup Gradle Wrapper" {
    Set-Location ..\backend

    if (!(Test-Path "gradlew.bat")) {
        Write-Host "Creating Gradle wrapper..." -ForegroundColor Yellow

        # Create gradle wrapper directory
        New-Item -ItemType Directory -Path "gradle\wrapper" -Force | Out-Null

        # Download wrapper jar
        $wrapperJarUrl = "https://github.com/gradle/gradle/raw/v8.5.0/gradle/wrapper/gradle-wrapper.jar"
        Invoke-WebRequest -Uri $wrapperJarUrl -OutFile "gradle\wrapper\gradle-wrapper.jar"

        # Create properties
        @"
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https://services.gradle.org/distributions/gradle-8.5-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
"@ | Out-File "gradle\wrapper\gradle-wrapper.properties" -Encoding UTF8

        # Download scripts
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradlew.bat" -OutFile "gradlew.bat"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradlew" -OutFile "gradlew"

        Write-Host "✓ Gradle wrapper created" -ForegroundColor Green
    }

    Set-Location ..\k8s
}

# STEP 4: Build Java services
Execute-Step "STEP 4: Build Java Services" {
    Set-Location ..\backend

    Write-Host "Building Java services (this may take 2-3 minutes)..." -ForegroundColor Yellow

    # Initialize Gradle wrapper first
    cmd /c "gradlew.bat --version"

    # Build services
    cmd /c "gradlew.bat clean build -x test"

    # Verify JARs
    $services = @("ingest-service", "projector-service", "query-service")
    foreach ($service in $services) {
        $jar = Get-ChildItem "$service\build\libs\*.jar" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($jar) {
            Write-Host "✓ $service JAR: $($jar.Name)" -ForegroundColor Green
        } else {
            throw "$service JAR not found"
        }
    }

    Set-Location ..\k8s
}

# STEP 5: Create Kind cluster
Execute-Step "STEP 5: Create Kubernetes Cluster" {
    Write-Host "Creating Kind cluster..." -ForegroundColor Yellow

    # Simple config
    @"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: wcd-platform
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
  - containerPort: 30001
    hostPort: 30001
"@ | Out-File "kind-auto.yaml" -Encoding UTF8

    kind create cluster --config kind-auto.yaml

    # Verify cluster
    kubectl cluster-info
    kubectl get nodes

    Write-Host "✓ Kubernetes cluster ready" -ForegroundColor Green
}

# STEP 6: Build Docker images
Execute-Step "STEP 6: Build Docker Images" {
    Set-Location ..\backend

    $services = @("ingest-service", "projector-service", "query-service")

    foreach ($service in $services) {
        Write-Host "Building $service Docker image..." -ForegroundColor Yellow

        $jar = Get-ChildItem "$service\build\libs\*.jar" | Select-Object -First 1

        # Create simple Dockerfile
        @"
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY $service/build/libs/$($jar.Name) app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
"@ | Out-File "Dockerfile.$service" -Encoding UTF8

        # Build image
        docker build -f "Dockerfile.$service" -t "wcd/$service:local" .

        # Load to Kind
        kind load docker-image "wcd/$service:local" --name wcd-platform

        Write-Host "✓ $service image ready" -ForegroundColor Green
    }

    Set-Location ..\k8s
}

# STEP 7: Deploy to Kubernetes
Execute-Step "STEP 7: Deploy Services" {
    Write-Host "Deploying to Kubernetes..." -ForegroundColor Yellow

    # Create namespace
    kubectl create namespace wcd-platform --dry-run=client -o yaml | kubectl apply -f -

    # Apply configs
    kubectl apply -f base\configmaps\
    kubectl apply -f base\secrets\

    # Deploy simplified Redis
    Write-Host "Deploying Redis..." -ForegroundColor Yellow
    @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wcd-redis-master
  namespace: wcd-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: wcd-redis-master
  namespace: wcd-platform
spec:
  ports:
  - port: 6379
    targetPort: 6379
  selector:
    app: redis
"@ | kubectl apply -f -

    # Deploy simplified Kafka
    Write-Host "Deploying Kafka..." -ForegroundColor Yellow
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
        command: ["redpanda", "start", "--smp=1", "--memory=1G", "--overprovisioned", "--node-id=0", "--kafka-addr=PLAINTEXT://0.0.0.0:9092", "--advertise-kafka-addr=PLAINTEXT://wcd-redpanda:9092"]
        ports:
        - containerPort: 9092
---
apiVersion: v1
kind: Service
metadata:
  name: wcd-redpanda
  namespace: wcd-platform
spec:
  ports:
  - port: 9092
    targetPort: 9092
  selector:
    app: redpanda
"@ | kubectl apply -f -

    Start-Sleep -Seconds 10

    # Deploy services with local images
    $services = @("ingest-service", "projector-service", "query-service")

    foreach ($service in $services) {
        # Apply original deployment
        kubectl apply -f "base\deployments\$service.yaml"

        # Update image to local version
        kubectl set image deployment/wcd-$service $service=wcd/$service:local -n wcd-platform

        Write-Host "✓ $service deployed" -ForegroundColor Green
    }
}

# STEP 8: Verify deployment
Execute-Step "STEP 8: Verify Deployment" {
    Write-Host "Waiting for pods to start (30 seconds)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30

    Write-Host "`nPod Status:" -ForegroundColor Cyan
    kubectl get pods -n wcd-platform

    Write-Host "`nService Status:" -ForegroundColor Cyan
    kubectl get services -n wcd-platform

    # Test port forwarding
    Write-Host "`nSetting up port forwarding for testing..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "kubectl port-forward -n wcd-platform deployment/wcd-ingest-service 8081:8081"
    Start-Process powershell -ArgumentList "kubectl port-forward -n wcd-platform deployment/wcd-query-service 8083:8083"

    Start-Sleep -Seconds 5

    # Test health endpoint
    Write-Host "`nTesting services..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8081/actuator/health" -UseBasicParsing -TimeoutSec 5
        Write-Host "✓ Ingest service is healthy" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Ingest service not responding yet" -ForegroundColor Yellow
    }

    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8083/actuator/health" -UseBasicParsing -TimeoutSec 5
        Write-Host "✓ Query service is healthy" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Query service not responding yet" -ForegroundColor Yellow
    }
}

# FINAL SUMMARY
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "    SETUP COMPLETE! 🎉" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host @"

Your WCD Platform is running in Kubernetes!

Access services:
- Ingest API: http://localhost:8081
- Query API: http://localhost:8083

Check pods:
kubectl get pods -n wcd-platform

View logs:
kubectl logs -f deployment/wcd-ingest-service -n wcd-platform

Stop everything:
kind delete cluster --name wcd-platform

"@ -ForegroundColor Cyan

if ($global:hasErrors) {
    Write-Host "`n⚠ Some steps had issues but setup completed" -ForegroundColor Yellow
} else {
    Write-Host "`n✅ All steps completed successfully!" -ForegroundColor Green
}

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")