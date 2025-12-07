# Simplified Kind Setup Script - Run after verify-and-setup.ps1
Write-Host "=== Simple Kind Setup ===" -ForegroundColor Green

# 1. Create a simple single-node Kind cluster
Write-Host "`nCreating single-node Kind cluster..." -ForegroundColor Yellow

# Simple configuration
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
  - containerPort: 30002
    hostPort: 30002
"@ | Out-File -FilePath "kind-simple.yaml" -Encoding UTF8

# Delete any existing cluster
kind delete cluster --name wcd-platform 2>$null

# Create new cluster
kind create cluster --config kind-simple.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create cluster. Trying without port mappings..." -ForegroundColor Yellow
    kind create cluster --name wcd-platform
}

# 2. Verify cluster is running
Write-Host "`nVerifying cluster..." -ForegroundColor Yellow
kubectl cluster-info

# Get nodes
kubectl get nodes

# 3. Install essential components
Write-Host "`nInstalling Metrics Server..." -ForegroundColor Yellow
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics server for Kind
kubectl patch deployment metrics-server -n kube-system --type='json' `
    -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# 4. Create storage class
Write-Host "`nCreating storage class..." -ForegroundColor Yellow
@"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
"@ | kubectl apply -f -

Write-Host "`n=== Kind Cluster Ready ===" -ForegroundColor Green
Write-Host "Cluster name: wcd-platform" -ForegroundColor Green
Write-Host "Context: kind-wcd-platform" -ForegroundColor Green
Write-Host "`nNext: Run .\build-and-deploy.ps1" -ForegroundColor Yellow