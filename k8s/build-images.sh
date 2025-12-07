#!/bin/bash

# Build and Load Docker Images for Kind Testing
# This script builds the service images locally and loads them into Kind

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
CLUSTER_NAME="wcd-platform"
REGISTRY="ghcr.io/curlyred/individual_semester_6"
TAG="latest"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if Kind cluster exists
check_cluster() {
    if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        print_error "Kind cluster '${CLUSTER_NAME}' not found!"
        print_status "Please run ./setup-kind.sh first"
        exit 1
    fi
}

# Build services
build_services() {
    print_status "Building service Docker images..."

    # Navigate to backend directory
    cd ../backend

    print_status "Building ingest-service..."
    docker build -f ingest-service/Dockerfile -t ${REGISTRY}/ingest-service:${TAG} .

    print_status "Building projector-service..."
    docker build -f projector-service/Dockerfile -t ${REGISTRY}/projector-service:${TAG} .

    print_status "Building query-service..."
    docker build -f query-service/Dockerfile -t ${REGISTRY}/query-service:${TAG} .

    # Build frontend if it exists
    if [ -d "../frontend" ]; then
        cd ../frontend
        print_status "Building frontend..."
        docker build -f Dockerfile -t ${REGISTRY}/frontend:${TAG} .
    fi

    cd ../k8s
    print_status "All images built successfully!"
}

# Load images to Kind
load_to_kind() {
    print_status "Loading images to Kind cluster..."

    print_status "Loading ingest-service..."
    kind load docker-image ${REGISTRY}/ingest-service:${TAG} --name ${CLUSTER_NAME}

    print_status "Loading projector-service..."
    kind load docker-image ${REGISTRY}/projector-service:${TAG} --name ${CLUSTER_NAME}

    print_status "Loading query-service..."
    kind load docker-image ${REGISTRY}/query-service:${TAG} --name ${CLUSTER_NAME}

    # Load frontend if it exists
    if docker image inspect ${REGISTRY}/frontend:${TAG} &>/dev/null; then
        print_status "Loading frontend..."
        kind load docker-image ${REGISTRY}/frontend:${TAG} --name ${CLUSTER_NAME}
    fi

    print_status "All images loaded to Kind!"
}

# Verify images in cluster
verify_images() {
    print_status "Verifying images in Kind cluster..."

    # Get a node name
    NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

    print_status "Images loaded in Kind node ${NODE}:"
    docker exec ${NODE} crictl images | grep -E "(REPOSITORY|individual_semester_6)" || true
}

# Update deployments to use local images
update_deployments() {
    print_status "Updating deployments to use local images..."

    # Update image pull policy to IfNotPresent for local images
    kubectl patch deployment wcd-ingest-service -n wcd-platform \
        -p '{"spec":{"template":{"spec":{"containers":[{"name":"ingest-service","imagePullPolicy":"IfNotPresent"}]}}}}'

    kubectl patch deployment wcd-projector-service -n wcd-platform \
        -p '{"spec":{"template":{"spec":{"containers":[{"name":"projector-service","imagePullPolicy":"IfNotPresent"}]}}}}'

    kubectl patch deployment wcd-query-service -n wcd-platform \
        -p '{"spec":{"template":{"spec":{"containers":[{"name":"query-service","imagePullPolicy":"IfNotPresent"}]}}}}'

    print_status "Deployments updated!"
}

# Restart deployments
restart_deployments() {
    print_status "Restarting deployments to use new images..."

    kubectl rollout restart deployment wcd-ingest-service -n wcd-platform
    kubectl rollout restart deployment wcd-projector-service -n wcd-platform
    kubectl rollout restart deployment wcd-query-service -n wcd-platform

    print_status "Waiting for rollout to complete..."
    kubectl rollout status deployment wcd-ingest-service -n wcd-platform
    kubectl rollout status deployment wcd-projector-service -n wcd-platform
    kubectl rollout status deployment wcd-query-service -n wcd-platform

    print_status "All services restarted with new images!"
}

# Show pod status
show_status() {
    print_status "Current pod status:"
    kubectl get pods -n wcd-platform
}

# Main execution
main() {
    print_status "Starting image build and load process..."

    check_cluster
    build_services
    load_to_kind
    verify_images

    # Check if namespace exists
    if kubectl get namespace wcd-platform &>/dev/null; then
        update_deployments
        restart_deployments
        show_status
    else
        print_warning "WCD Platform not deployed yet. Run: ./deploy.sh local apply"
    fi

    print_status "Done! Images are ready in Kind cluster."
}

main "$@"