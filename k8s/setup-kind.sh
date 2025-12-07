#!/bin/bash

# Kind Local Kubernetes Setup Script for WCD Platform
# This script sets up a local Kubernetes cluster using Kind (Kubernetes in Docker)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="wcd-platform"
KIND_VERSION="v0.20.0"
KUBECTL_VERSION="v1.29.0"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Check if running on Windows with Git Bash or WSL
check_environment() {
    print_section "Checking Environment"

    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        print_status "Running on Windows (Git Bash/Cygwin detected)"
        WINDOWS_ENV=true
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        print_status "Running on WSL"
        WINDOWS_ENV=true
    else
        print_status "Running on Linux/MacOS"
        WINDOWS_ENV=false
    fi
}

# Check Docker
check_docker() {
    print_section "Checking Docker"

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        print_status "Please install Docker Desktop: https://www.docker.com/products/docker-desktop"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        print_status "Please start Docker Desktop"
        exit 1
    fi

    print_status "Docker is running"
    docker version --format "Docker version: {{.Server.Version}}"
}

# Install Kind
install_kind() {
    print_section "Installing Kind"

    if command -v kind &> /dev/null; then
        INSTALLED_VERSION=$(kind version | cut -d ' ' -f 2)
        print_status "Kind is already installed (version: $INSTALLED_VERSION)"
        read -p "Do you want to reinstall/update Kind? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    print_status "Installing Kind ${KIND_VERSION}..."

    if [[ "$WINDOWS_ENV" == true ]]; then
        # Windows installation
        curl -Lo kind.exe https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-windows-amd64
        chmod +x kind.exe
        if [[ -d "/c/tools" ]]; then
            mv kind.exe /c/tools/kind.exe
            print_status "Kind installed to /c/tools/"
            print_warning "Make sure /c/tools is in your PATH"
        else
            mkdir -p ~/bin
            mv kind.exe ~/bin/kind.exe
            print_status "Kind installed to ~/bin/"
            print_warning "Add ~/bin to your PATH: export PATH=\$PATH:~/bin"
        fi
    else
        # Linux/MacOS installation
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # MacOS
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-darwin-arm64
        else
            # Linux
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
        fi
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        print_status "Kind installed to /usr/local/bin/"
    fi

    # Verify installation
    if command -v kind &> /dev/null; then
        print_status "Kind installed successfully: $(kind version)"
    else
        print_error "Kind installation failed"
        exit 1
    fi
}

# Install kubectl
install_kubectl() {
    print_section "Installing kubectl"

    if command -v kubectl &> /dev/null; then
        INSTALLED_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d ':' -f 2 | tr -d ' ')
        print_status "kubectl is already installed (version: $INSTALLED_VERSION)"
        return
    fi

    print_status "Installing kubectl ${KUBECTL_VERSION}..."

    if [[ "$WINDOWS_ENV" == true ]]; then
        # Windows installation
        curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/windows/amd64/kubectl.exe
        chmod +x kubectl.exe
        if [[ -d "/c/tools" ]]; then
            mv kubectl.exe /c/tools/kubectl.exe
        else
            mkdir -p ~/bin
            mv kubectl.exe ~/bin/kubectl.exe
        fi
    else
        # Linux/MacOS installation
        if [[ "$OSTYPE" == "darwin"* ]]; then
            curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/darwin/arm64/kubectl"
        else
            curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
        fi
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/kubectl
    fi

    if command -v kubectl &> /dev/null; then
        print_status "kubectl installed successfully"
    else
        print_error "kubectl installation failed"
        exit 1
    fi
}

# Create Kind cluster
create_cluster() {
    print_section "Creating Kind Cluster"

    # Check if cluster already exists
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        print_warning "Cluster '${CLUSTER_NAME}' already exists"
        read -p "Do you want to delete and recreate it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Deleting existing cluster..."
            kind delete cluster --name ${CLUSTER_NAME}
        else
            print_status "Using existing cluster"
            return
        fi
    fi

    print_status "Creating Kind cluster '${CLUSTER_NAME}'..."
    print_status "This may take 2-5 minutes..."

    # Create data directory for persistent volumes
    mkdir -p ./data

    # Create cluster with configuration
    kind create cluster --config kind-config.yaml

    print_status "Cluster created successfully!"

    # Set kubectl context
    kubectl cluster-info --context kind-${CLUSTER_NAME}
}

# Install Ingress Controller
install_ingress() {
    print_section "Installing NGINX Ingress Controller"

    print_status "Installing NGINX Ingress Controller for Kind..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    print_status "Waiting for Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s

    print_status "Ingress Controller installed successfully!"
}

# Install Metrics Server
install_metrics_server() {
    print_section "Installing Metrics Server"

    print_status "Installing Metrics Server for HPA..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    # Patch metrics server for Kind (disable TLS verification)
    kubectl patch -n kube-system deployment metrics-server --type=json \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

    print_status "Waiting for Metrics Server to be ready..."
    kubectl wait --namespace kube-system \
        --for=condition=ready pod \
        --selector=k8s-app=metrics-server \
        --timeout=120s

    print_status "Metrics Server installed successfully!"
}

# Install Local Storage Provisioner
install_storage() {
    print_section "Installing Storage Provisioner"

    print_status "Creating storage class for persistent volumes..."

    cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF

    print_status "Storage provisioner configured!"
}

# Load Docker images to Kind
load_images() {
    print_section "Loading Docker Images to Kind"

    print_status "This step loads local Docker images into the Kind cluster"
    print_warning "Make sure your services are built as Docker images first!"

    # Check if images exist
    if docker image inspect ghcr.io/curlyred/individual_semester_6/ingest-service:latest &>/dev/null; then
        print_status "Loading ingest-service..."
        kind load docker-image ghcr.io/curlyred/individual_semester_6/ingest-service:latest --name ${CLUSTER_NAME}
    else
        print_warning "ingest-service image not found locally"
    fi

    if docker image inspect ghcr.io/curlyred/individual_semester_6/projector-service:latest &>/dev/null; then
        print_status "Loading projector-service..."
        kind load docker-image ghcr.io/curlyred/individual_semester_6/projector-service:latest --name ${CLUSTER_NAME}
    else
        print_warning "projector-service image not found locally"
    fi

    if docker image inspect ghcr.io/curlyred/individual_semester_6/query-service:latest &>/dev/null; then
        print_status "Loading query-service..."
        kind load docker-image ghcr.io/curlyred/individual_semester_6/query-service:latest --name ${CLUSTER_NAME}
    else
        print_warning "query-service image not found locally"
    fi

    print_status "You can load images manually with: kind load docker-image <image-name> --name ${CLUSTER_NAME}"
}

# Deploy WCD Platform
deploy_platform() {
    print_section "Deploying WCD Platform"

    read -p "Do you want to deploy the WCD Platform now? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Skipping deployment. You can deploy later with: ./deploy.sh local apply"
        return
    fi

    print_status "Deploying WCD Platform to Kind cluster..."

    if [[ -f "./deploy.sh" ]]; then
        chmod +x ./deploy.sh
        ./deploy.sh local apply
    else
        print_warning "deploy.sh not found. Deploying manually..."
        kubectl apply -k base/
    fi

    print_status "Platform deployed!"
}

# Show access information
show_info() {
    print_section "Cluster Information"

    echo -e "${GREEN}Cluster is ready!${NC}"
    echo ""
    echo "Cluster name: ${CLUSTER_NAME}"
    echo "Kubectl context: kind-${CLUSTER_NAME}"
    echo ""
    echo "Access URLs (after deployment):"
    echo "  - API: http://localhost/"
    echo "  - Ingest Service: http://localhost:30000"
    echo "  - Query Service: http://localhost:30001"
    echo "  - Grafana: http://localhost:30002"
    echo ""
    echo "Useful commands:"
    echo "  - Check pods: kubectl get pods -n wcd-platform"
    echo "  - Check logs: kubectl logs -f <pod-name> -n wcd-platform"
    echo "  - Port forward: kubectl port-forward -n wcd-platform svc/<service> <local>:<remote>"
    echo "  - Delete cluster: kind delete cluster --name ${CLUSTER_NAME}"
    echo ""
    echo "Next steps:"
    echo "  1. Build your service images locally"
    echo "  2. Load them to Kind: kind load docker-image <image> --name ${CLUSTER_NAME}"
    echo "  3. Deploy the platform: ./deploy.sh local apply"
    echo "  4. Test with k6: cd ../k6 && k6 run baseline.js"
}

# Main execution
main() {
    print_section "WCD Platform - Kind Setup"

    check_environment
    check_docker
    install_kind
    install_kubectl
    create_cluster
    install_ingress
    install_metrics_server
    install_storage
    load_images
    deploy_platform
    show_info

    print_section "Setup Complete!"
    print_status "Your local Kubernetes cluster is ready for testing!"
}

# Run main function
main "$@"