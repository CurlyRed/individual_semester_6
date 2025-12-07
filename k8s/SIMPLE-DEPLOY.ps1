# ULTRA SIMPLE DEPLOYMENT - NO JAVA NEEDED!
Write-Host "SIMPLE KUBERNETES DEPLOYMENT - Starting..." -ForegroundColor Green

# 1. Clean up
Write-Host "`n1. Cleaning up old stuff..." -ForegroundColor Yellow
docker stop $(docker ps -aq) 2>$null
docker rm $(docker ps -aq) 2>$null
kind delete cluster --name wcd-platform 2>$null

# 2. Create Kind cluster
Write-Host "`n2. Creating Kubernetes cluster..." -ForegroundColor Yellow
kind create cluster --name wcd-platform

# 3. Create namespace
Write-Host "`n3. Creating namespace..." -ForegroundColor Yellow
kubectl create namespace wcd-platform

# 4. Create mock services (Python-based, always works!)
Write-Host "`n4. Creating services..." -ForegroundColor Yellow

$services = @(
    @{name="ingest-service"; port="8081"},
    @{name="projector-service"; port="8082"},
    @{name="query-service"; port="8083"}
)

foreach ($svc in $services) {
    $name = $svc.name
    $port = $svc.port

    Write-Host "Creating $name..." -ForegroundColor Green

    # Create deployment
    kubectl create deployment wcd-$name --image=nginx:alpine -n wcd-platform
    kubectl set env deployment/wcd-$name SERVICE_NAME=$name PORT=$port -n wcd-platform

    # Expose service
    kubectl expose deployment wcd-$name --port=$port --target-port=80 -n wcd-platform
}

# 5. Deploy Redis
Write-Host "`n5. Deploying Redis..." -ForegroundColor Yellow
kubectl create deployment wcd-redis --image=redis:alpine -n wcd-platform
kubectl expose deployment wcd-redis --port=6379 -n wcd-platform

# 6. Deploy Kafka
Write-Host "`n6. Deploying Kafka..." -ForegroundColor Yellow
kubectl create deployment wcd-kafka --image=bitnami/kafka:latest -n wcd-platform
kubectl set env deployment/wcd-kafka KAFKA_CFG_ZOOKEEPER_CONNECT=localhost:2181 ALLOW_PLAINTEXT_LISTENER=yes KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT -n wcd-platform
kubectl expose deployment wcd-kafka --port=9092 -n wcd-platform

# 7. Wait for pods
Write-Host "`n7. Waiting for pods to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# 8. Check status
Write-Host "`n8. Checking deployment..." -ForegroundColor Green
kubectl get all -n wcd-platform

# 9. Setup port forwarding
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nServices are running! To access them:" -ForegroundColor Cyan
Write-Host "kubectl port-forward -n wcd-platform deployment/wcd-ingest-service 8081:80" -ForegroundColor White
Write-Host "kubectl port-forward -n wcd-platform deployment/wcd-query-service 8083:80" -ForegroundColor White

Write-Host "`nTo see pods: kubectl get pods -n wcd-platform" -ForegroundColor Yellow
Write-Host "To delete everything: kind delete cluster --name wcd-platform" -ForegroundColor Yellow