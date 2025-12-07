# Build and Deploy Script - Run after Kind cluster is created
Write-Host "=== Build and Deploy WCD Platform ===" -ForegroundColor Green

$backendPath = "..\backend"
$services = @("ingest-service", "projector-service", "query-service")

# 1. Build Java services
Write-Host "`nStep 1: Building Java services..." -ForegroundColor Yellow

Set-Location $backendPath

# Check if gradlew exists
if (Test-Path "gradlew.bat") {
    Write-Host "Building with Gradle..." -ForegroundColor Green
    .\gradlew.bat clean build -x test

    # Verify JARs exist
    foreach ($service in $services) {
        $jar = Get-ChildItem "$service\build\libs\*.jar" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($jar) {
            Write-Host "✓ $service JAR ready: $($jar.Name)" -ForegroundColor Green
        } else {
            Write-Host "✗ $service JAR missing!" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host "gradlew.bat not found!" -ForegroundColor Red
    Write-Host "Run verify-and-setup.ps1 first" -ForegroundColor Yellow
    exit 1
}

# 2. Create optimized Dockerfiles
Write-Host "`nStep 2: Creating Docker images..." -ForegroundColor Yellow

foreach ($service in $services) {
    Write-Host "Building $service Docker image..." -ForegroundColor Green

    # Find the JAR file
    $jar = Get-ChildItem "$service\build\libs\*.jar" | Select-Object -First 1

    # Create a simple Dockerfile that uses the pre-built JAR
    $dockerfileContent = @"
FROM eclipse-temurin:21-jre-alpine
RUN apk add --no-cache curl
WORKDIR /app
COPY $service/build/libs/$($jar.Name) app.jar
EXPOSE 8080 8081 8082 8083
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "app.jar"]
"@

    $dockerfilePath = "$backendPath\Dockerfile.$service"
    $dockerfileContent | Out-File -FilePath $dockerfilePath -Encoding UTF8

    # Build the image
    docker build -f $dockerfilePath -t "local/$service:latest" $backendPath

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ $service image built" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to build $service image" -ForegroundColor Red
        exit 1
    }
}

# 3. Load images to Kind
Write-Host "`nStep 3: Loading images to Kind..." -ForegroundColor Yellow

foreach ($service in $services) {
    Write-Host "Loading $service..." -ForegroundColor Green
    kind load docker-image "local/$service:latest" --name wcd-platform

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ $service loaded to Kind" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to load $service" -ForegroundColor Red
    }
}

# 4. Update Kubernetes manifests to use local images
Write-Host "`nStep 4: Updating manifests for local images..." -ForegroundColor Yellow

Set-Location ..\k8s

# Create modified deployments that use local images
foreach ($service in $services) {
    $deploymentFile = "base\deployments\$service.yaml"
    if (Test-Path $deploymentFile) {
        $content = Get-Content $deploymentFile -Raw

        # Replace image references
        $content = $content -replace "ghcr.io/curlyred/individual_semester_6/$service:latest", "local/$service:latest"
        $content = $content -replace "imagePullPolicy: Always", "imagePullPolicy: IfNotPresent"

        # Save to a local version
        $content | Out-File -FilePath "base\deployments\$service-local.yaml" -Encoding UTF8
        Write-Host "✓ Updated $service deployment" -ForegroundColor Green
    }
}

# 5. Deploy to Kubernetes
Write-Host "`nStep 5: Deploying to Kubernetes..." -ForegroundColor Yellow

# Create namespace
kubectl create namespace wcd-platform --dry-run=client -o yaml | kubectl apply -f -

# Apply configs and secrets
Write-Host "Applying configurations..." -ForegroundColor Green
kubectl apply -f base\configmaps\
kubectl apply -f base\secrets\

# Deploy Redis and Redpanda first
Write-Host "Deploying databases..." -ForegroundColor Green
kubectl apply -f base\statefulsets\redis.yaml

# For Redpanda, we'll use a simpler setup
Write-Host "Creating simplified Redpanda deployment..." -ForegroundColor Green
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
          name: kafka
        - containerPort: 9644
          name: admin
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: wcd-redpanda
  namespace: wcd-platform
spec:
  ports:
  - name: kafka
    port: 9092
    targetPort: 9092
  - name: admin
    port: 9644
    targetPort: 9644
  selector:
    app: redpanda
"@ | kubectl apply -f -

Write-Host "Waiting for databases to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Deploy microservices using local versions
Write-Host "Deploying microservices..." -ForegroundColor Green
foreach ($service in $services) {
    $localFile = "base\deployments\$service-local.yaml"
    if (Test-Path $localFile) {
        kubectl apply -f $localFile
    } else {
        # Fallback: apply original with kubectl set image
        kubectl apply -f "base\deployments\$service.yaml"
        kubectl set image deployment/wcd-$service $service=local/$service:latest -n wcd-platform
    }
}

# 6. Check deployment status
Write-Host "`nStep 6: Checking deployment status..." -ForegroundColor Yellow

# Wait a bit for pods to start
Start-Sleep -Seconds 10

# Check pods
kubectl get pods -n wcd-platform

# Check services
kubectl get services -n wcd-platform

# 7. Setup port forwarding for testing
Write-Host "`nStep 7: Port forwarding setup..." -ForegroundColor Yellow

Write-Host @"

Deployment complete! To access services, run these commands in separate terminals:

kubectl port-forward -n wcd-platform deployment/wcd-ingest-service 8081:8081
kubectl port-forward -n wcd-platform deployment/wcd-query-service 8083:8083
kubectl port-forward -n wcd-platform deployment/wcd-redis-master 6379:6379

Or use NodePort access:
- Ingest: http://localhost:30000
- Query: http://localhost:30001

Check logs:
kubectl logs -f deployment/wcd-ingest-service -n wcd-platform
kubectl logs -f deployment/wcd-query-service -n wcd-platform

"@ -ForegroundColor Green

Write-Host "=== Deployment Complete ===" -ForegroundColor Green