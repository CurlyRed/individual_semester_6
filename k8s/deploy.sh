#!/bin/bash

# WCD Platform Kubernetes Deployment Script
# Usage: ./deploy.sh [environment] [action]
# Environments: local, dev, staging, prod
# Actions: apply, delete, status

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-local}
ACTION=${2:-apply}
NAMESPACE="wcd-platform"
KUBECTL_CMD="kubectl"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check current context
CURRENT_CONTEXT=$(kubectl config current-context)
print_status "Current Kubernetes context: $CURRENT_CONTEXT"

# Safety check for production
if [[ "$ENVIRONMENT" == "prod" ]]; then
    print_warning "You are about to deploy to PRODUCTION!"
    read -p "Are you sure? Type 'yes' to continue: " -r
    if [[ ! $REPLY == "yes" ]]; then
        print_error "Production deployment cancelled."
        exit 1
    fi
fi

# Function to apply resources
apply_resources() {
    print_status "Deploying to environment: $ENVIRONMENT"

    # Create namespace
    print_status "Creating namespace..."
    $KUBECTL_CMD apply -f base/namespace/namespace.yaml

    # Wait for namespace to be ready
    sleep 2

    # Apply ConfigMaps and Secrets
    print_status "Applying ConfigMaps and Secrets..."
    $KUBECTL_CMD apply -f base/configmaps/
    $KUBECTL_CMD apply -f base/secrets/

    # Deploy databases (StatefulSets)
    print_status "Deploying databases..."
    $KUBECTL_CMD apply -f base/statefulsets/redis.yaml
    $KUBECTL_CMD apply -f base/statefulsets/redpanda.yaml

    # Wait for databases to be ready
    print_status "Waiting for databases to be ready..."
    $KUBECTL_CMD wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=120s || true
    $KUBECTL_CMD wait --for=condition=ready pod -l app=redpanda -n $NAMESPACE --timeout=120s || true

    # Deploy microservices
    print_status "Deploying microservices..."
    $KUBECTL_CMD apply -f base/deployments/

    # Deploy monitoring
    print_status "Deploying monitoring stack..."
    $KUBECTL_CMD apply -f base/monitoring/

    # Apply Ingress
    print_status "Applying Ingress rules..."
    $KUBECTL_CMD apply -f base/ingress/

    print_status "Deployment complete!"
}

# Function to delete resources
delete_resources() {
    print_warning "Deleting all resources in namespace: $NAMESPACE"
    read -p "Are you sure? Type 'yes' to continue: " -r
    if [[ ! $REPLY == "yes" ]]; then
        print_error "Deletion cancelled."
        exit 1
    fi

    $KUBECTL_CMD delete namespace $NAMESPACE --ignore-not-found=true
    print_status "All resources deleted."
}

# Function to check status
check_status() {
    print_status "Checking deployment status..."

    echo -e "\n${GREEN}=== Namespace ===${NC}"
    $KUBECTL_CMD get namespace $NAMESPACE

    echo -e "\n${GREEN}=== Pods ===${NC}"
    $KUBECTL_CMD get pods -n $NAMESPACE

    echo -e "\n${GREEN}=== Services ===${NC}"
    $KUBECTL_CMD get services -n $NAMESPACE

    echo -e "\n${GREEN}=== Deployments ===${NC}"
    $KUBECTL_CMD get deployments -n $NAMESPACE

    echo -e "\n${GREEN}=== StatefulSets ===${NC}"
    $KUBECTL_CMD get statefulsets -n $NAMESPACE

    echo -e "\n${GREEN}=== Ingress ===${NC}"
    $KUBECTL_CMD get ingress -n $NAMESPACE

    echo -e "\n${GREEN}=== HPA ===${NC}"
    $KUBECTL_CMD get hpa -n $NAMESPACE

    echo -e "\n${GREEN}=== PVCs ===${NC}"
    $KUBECTL_CMD get pvc -n $NAMESPACE
}

# Function to port-forward services for local testing
port_forward() {
    print_status "Setting up port forwarding for local access..."

    # Kill any existing port-forward processes
    pkill -f "kubectl port-forward" || true

    # Port forward services
    $KUBECTL_CMD port-forward -n $NAMESPACE service/wcd-ingest-service 8081:8081 &
    $KUBECTL_CMD port-forward -n $NAMESPACE service/wcd-query-service 8083:8083 &
    $KUBECTL_CMD port-forward -n $NAMESPACE service/wcd-grafana 3000:3000 &
    $KUBECTL_CMD port-forward -n $NAMESPACE service/wcd-jaeger-query 16686:16686 &

    print_status "Port forwarding established:"
    echo "  - Ingest Service: http://localhost:8081"
    echo "  - Query Service: http://localhost:8083"
    echo "  - Grafana: http://localhost:3000"
    echo "  - Jaeger: http://localhost:16686"
    echo ""
    print_warning "Press Ctrl+C to stop port forwarding"

    # Wait
    wait
}

# Function to run tests
run_tests() {
    print_status "Running smoke tests..."

    # Check if services are responding
    INGEST_POD=$(kubectl get pod -n $NAMESPACE -l app=ingest-service -o jsonpath="{.items[0].metadata.name}")
    QUERY_POD=$(kubectl get pod -n $NAMESPACE -l app=query-service -o jsonpath="{.items[0].metadata.name}")

    print_status "Testing Ingest Service health..."
    $KUBECTL_CMD exec -n $NAMESPACE $INGEST_POD -- wget -q -O- http://localhost:8081/actuator/health || print_error "Ingest service health check failed"

    print_status "Testing Query Service health..."
    $KUBECTL_CMD exec -n $NAMESPACE $QUERY_POD -- wget -q -O- http://localhost:8083/actuator/health || print_error "Query service health check failed"

    print_status "Smoke tests complete!"
}

# Main execution
case $ACTION in
    apply)
        apply_resources
        ;;
    delete)
        delete_resources
        ;;
    status)
        check_status
        ;;
    port-forward)
        port_forward
        ;;
    test)
        run_tests
        ;;
    *)
        print_error "Unknown action: $ACTION"
        echo "Usage: $0 [environment] [action]"
        echo "Environments: local, dev, staging, prod"
        echo "Actions: apply, delete, status, port-forward, test"
        exit 1
        ;;
esac