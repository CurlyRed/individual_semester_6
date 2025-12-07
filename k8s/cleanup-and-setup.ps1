# PowerShell script for Windows to clean Docker and setup Kind
# Run with: powershell -ExecutionPolicy Bypass -File cleanup-and-setup.ps1

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Docker Cleanup and Kind Setup" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Function to show Docker usage
function Show-DockerUsage {
    Write-Host "Current Docker Disk Usage:" -ForegroundColor Yellow
    docker system df
    Write-Host ""
}

# Function to clean Docker
function Clean-Docker {
    Write-Host "Starting Docker Cleanup..." -ForegroundColor Green

    # Show what will be cleaned
    Write-Host "This will remove:" -ForegroundColor Yellow
    Write-Host "  - All stopped containers"
    Write-Host "  - All unused networks"
    Write-Host "  - All unused images"
    Write-Host "  - All build cache"
    Write-Host "  - All volumes"
    Write-Host ""

    $confirm = Read-Host "Continue with cleanup? (y/n)"
    if ($confirm -ne 'y') {
        Write-Host "Cleanup cancelled" -ForegroundColor Red
        return
    }

    Write-Host "Stopping all containers..." -ForegroundColor Green
    docker stop $(docker ps -q) 2>$null

    Write-Host "Removing containers..." -ForegroundColor Green
    docker container prune -f

    Write-Host "Removing volumes..." -ForegroundColor Green
    docker volume prune -f

    Write-Host "Removing images..." -ForegroundColor Green
    docker image prune -a -f

    Write-Host "Cleaning build cache..." -ForegroundColor Green
    docker builder prune -f

    Write-Host "Removing networks..." -ForegroundColor Green
    docker network prune -f

    Write-Host "Running full system prune..." -ForegroundColor Green
    docker system prune -a --volumes -f

    Write-Host "Docker cleanup complete!" -ForegroundColor Green
}

# Function to delete Kind clusters
function Clean-KindClusters {
    Write-Host "Checking for Kind clusters..." -ForegroundColor Green

    try {
        $clusters = kind get clusters 2>$null
        if ($clusters) {
            Write-Host "Found clusters: $clusters" -ForegroundColor Yellow
            $confirm = Read-Host "Delete all Kind clusters? (y/n)"
            if ($confirm -eq 'y') {
                foreach ($cluster in $clusters) {
                    Write-Host "Deleting cluster: $cluster" -ForegroundColor Green
                    kind delete cluster --name $cluster
                }
            }
        } else {
            Write-Host "No Kind clusters found" -ForegroundColor Green
        }
    } catch {
        Write-Host "Kind not installed yet" -ForegroundColor Yellow
    }
}

# Function to restart Docker Desktop
function Restart-DockerDesktop {
    Write-Host "Restarting Docker Desktop..." -ForegroundColor Green

    # Stop Docker Desktop
    Write-Host "Stopping Docker Desktop..." -ForegroundColor Yellow
    Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name com.docker.service -Force -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 5

    # Start Docker Desktop
    Write-Host "Starting Docker Desktop..." -ForegroundColor Yellow
    $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerPath) {
        Start-Process $dockerPath
    } else {
        Write-Host "Please start Docker Desktop manually" -ForegroundColor Red
    }

    # Wait for Docker to be ready
    Write-Host "Waiting for Docker to be ready..." -ForegroundColor Yellow
    $maxWait = 60
    $waited = 0
    while ($waited -lt $maxWait) {
        try {
            docker info 2>$null | Out-Null
            Write-Host "Docker is ready!" -ForegroundColor Green
            break
        } catch {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 2
            $waited += 2
        }
    }
    Write-Host ""
}

# Function to setup Kind
function Setup-Kind {
    Write-Host ""
    Write-Host "Setting up Kind cluster..." -ForegroundColor Green

    # Check if Kind is installed
    try {
        kind version | Out-Null
        Write-Host "Kind is installed" -ForegroundColor Green
    } catch {
        Write-Host "Installing Kind..." -ForegroundColor Yellow

        # Download Kind
        $kindUrl = "https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64"
        $kindPath = "$env:TEMP\kind.exe"

        Write-Host "Downloading Kind..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $kindUrl -OutFile $kindPath

        # Move to a directory in PATH
        $installPath = "C:\tools"
        if (!(Test-Path $installPath)) {
            New-Item -ItemType Directory -Path $installPath -Force
        }

        Move-Item -Path $kindPath -Destination "$installPath\kind.exe" -Force

        # Add to PATH if not already there
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$installPath*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installPath", "User")
            $env:Path = "$env:Path;$installPath"
        }

        Write-Host "Kind installed successfully" -ForegroundColor Green
    }

    # Create Kind cluster
    Write-Host "Creating Kind cluster 'wcd-platform'..." -ForegroundColor Green

    # Check if cluster exists
    $clusters = kind get clusters 2>$null
    if ($clusters -contains "wcd-platform") {
        Write-Host "Cluster already exists, deleting..." -ForegroundColor Yellow
        kind delete cluster --name wcd-platform
    }

    # Create cluster
    if (Test-Path "kind-config.yaml") {
        kind create cluster --config kind-config.yaml
    } else {
        Write-Host "kind-config.yaml not found, creating basic cluster..." -ForegroundColor Yellow
        kind create cluster --name wcd-platform
    }

    Write-Host "Kind cluster created!" -ForegroundColor Green
}

# Function to install kubectl
function Install-Kubectl {
    Write-Host "Checking kubectl..." -ForegroundColor Green

    try {
        kubectl version --client | Out-Null
        Write-Host "kubectl is installed" -ForegroundColor Green
    } catch {
        Write-Host "Installing kubectl..." -ForegroundColor Yellow

        # Download kubectl
        $kubectlUrl = "https://dl.k8s.io/release/v1.29.0/bin/windows/amd64/kubectl.exe"
        $kubectlPath = "$env:TEMP\kubectl.exe"

        Write-Host "Downloading kubectl..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $kubectlUrl -OutFile $kubectlPath

        # Move to tools directory
        $installPath = "C:\tools"
        if (!(Test-Path $installPath)) {
            New-Item -ItemType Directory -Path $installPath -Force
        }

        Move-Item -Path $kubectlPath -Destination "$installPath\kubectl.exe" -Force

        Write-Host "kubectl installed successfully" -ForegroundColor Green
    }
}

# Function to install Ingress controller
function Install-IngressController {
    Write-Host "Installing NGINX Ingress Controller..." -ForegroundColor Green

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    Write-Host "Waiting for Ingress Controller..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30

    kubectl wait --namespace ingress-nginx `
        --for=condition=ready pod `
        --selector=app.kubernetes.io/component=controller `
        --timeout=120s

    Write-Host "Ingress Controller ready!" -ForegroundColor Green
}

# Function to build and deploy
function Deploy-Platform {
    Write-Host ""
    Write-Host "Building and deploying WCD Platform..." -ForegroundColor Green

    # Build Docker images
    Write-Host "Building Docker images..." -ForegroundColor Yellow

    Set-Location ../backend
    docker build -f ingest-service/Dockerfile -t ghcr.io/curlyred/individual_semester_6/ingest-service:latest .
    docker build -f projector-service/Dockerfile -t ghcr.io/curlyred/individual_semester_6/projector-service:latest .
    docker build -f query-service/Dockerfile -t ghcr.io/curlyred/individual_semester_6/query-service:latest .
    Set-Location ../k8s

    # Load images to Kind
    Write-Host "Loading images to Kind..." -ForegroundColor Yellow
    kind load docker-image ghcr.io/curlyred/individual_semester_6/ingest-service:latest --name wcd-platform
    kind load docker-image ghcr.io/curlyred/individual_semester_6/projector-service:latest --name wcd-platform
    kind load docker-image ghcr.io/curlyred/individual_semester_6/query-service:latest --name wcd-platform

    # Deploy to Kubernetes
    Write-Host "Deploying to Kubernetes..." -ForegroundColor Yellow
    kubectl apply -k base/

    Write-Host "Deployment started!" -ForegroundColor Green
}

# Function to check deployment status
function Check-Deployment {
    Write-Host ""
    Write-Host "Checking deployment status..." -ForegroundColor Green

    kubectl get pods -n wcd-platform
    Write-Host ""
    kubectl get services -n wcd-platform
    Write-Host ""
    kubectl get hpa -n wcd-platform
}

# Main execution
Write-Host "=== Step 1: Docker Cleanup ===" -ForegroundColor Cyan
Show-DockerUsage
Clean-Docker
Clean-KindClusters

$restartDocker = Read-Host "Restart Docker Desktop? (y/n)"
if ($restartDocker -eq 'y') {
    Restart-DockerDesktop
}

Write-Host ""
Write-Host "=== Step 2: Setup Kind ===" -ForegroundColor Cyan
Install-Kubectl
Setup-Kind
Install-IngressController

Write-Host ""
Write-Host "=== Step 3: Deploy Platform ===" -ForegroundColor Cyan
$deploy = Read-Host "Deploy WCD Platform now? (y/n)"
if ($deploy -eq 'y') {
    Deploy-Platform
    Start-Sleep -Seconds 30
    Check-Deployment
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Access services with port-forward:" -ForegroundColor Yellow
Write-Host "  kubectl port-forward -n wcd-platform svc/wcd-ingest-service 8081:8081"
Write-Host "  kubectl port-forward -n wcd-platform svc/wcd-query-service 8083:8083"
Write-Host ""
Write-Host "Check pods: kubectl get pods -n wcd-platform" -ForegroundColor Yellow
Write-Host "Check logs: kubectl logs -f <pod-name> -n wcd-platform" -ForegroundColor Yellow