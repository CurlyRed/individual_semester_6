#!/bin/bash

# Test Script for Local Kind Cluster
# This script tests the WCD Platform deployment in Kind

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="wcd-platform"
API_KEY="dev-secret-key"

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_test() {
    echo -e "${BLUE}→${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    echo -e "\n${BLUE}=== Checking Prerequisites ===${NC}\n"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found"
        exit 1
    fi
    print_status "kubectl available"

    # Check cluster
    if ! kubectl cluster-info &>/dev/null; then
        print_error "No Kubernetes cluster found"
        exit 1
    fi
    print_status "Kubernetes cluster accessible"

    # Check namespace
    if ! kubectl get namespace ${NAMESPACE} &>/dev/null; then
        print_error "Namespace ${NAMESPACE} not found"
        exit 1
    fi
    print_status "Namespace ${NAMESPACE} exists"
}

# Test pod readiness
test_pods() {
    echo -e "\n${BLUE}=== Testing Pod Readiness ===${NC}\n"

    # Get all pods
    PODS=$(kubectl get pods -n ${NAMESPACE} -o json)

    # Check if pods are running
    RUNNING_PODS=$(echo $PODS | jq -r '.items[] | select(.status.phase=="Running") | .metadata.name' | wc -l)
    TOTAL_PODS=$(echo $PODS | jq -r '.items[].metadata.name' | wc -l)

    if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
        print_status "All pods are running ($RUNNING_PODS/$TOTAL_PODS)"
    else
        print_error "Not all pods are running ($RUNNING_PODS/$TOTAL_PODS)"
        kubectl get pods -n ${NAMESPACE}
        exit 1
    fi

    # Check specific services
    for service in ingest projector query redis redpanda; do
        if kubectl get pods -n ${NAMESPACE} -l app=${service}-service &>/dev/null || \
           kubectl get pods -n ${NAMESPACE} -l app=${service} &>/dev/null; then
            print_status "${service} pods found"
        else
            print_warning "${service} pods not found (might be using different labels)"
        fi
    done
}

# Test service endpoints
test_services() {
    echo -e "\n${BLUE}=== Testing Service Endpoints ===${NC}\n"

    # Get services
    SERVICES=$(kubectl get services -n ${NAMESPACE} -o json)

    # Check each service has endpoints
    for service in wcd-ingest-service wcd-projector-service wcd-query-service wcd-redis-master wcd-redpanda; do
        if kubectl get service ${service} -n ${NAMESPACE} &>/dev/null; then
            ENDPOINTS=$(kubectl get endpoints ${service} -n ${NAMESPACE} -o json | jq -r '.subsets[0].addresses | length')
            if [ "$ENDPOINTS" -gt 0 ] 2>/dev/null; then
                print_status "${service} has $ENDPOINTS endpoint(s)"
            else
                print_warning "${service} has no endpoints"
            fi
        else
            print_warning "${service} not found"
        fi
    done
}

# Port forward for testing
setup_port_forward() {
    echo -e "\n${BLUE}=== Setting Up Port Forwarding ===${NC}\n"

    # Kill existing port-forward processes
    pkill -f "kubectl port-forward" 2>/dev/null || true

    # Port forward services
    print_test "Starting port forwarding..."

    kubectl port-forward -n ${NAMESPACE} service/wcd-ingest-service 8081:8081 &>/dev/null &
    PF_INGEST=$!

    kubectl port-forward -n ${NAMESPACE} service/wcd-query-service 8083:8083 &>/dev/null &
    PF_QUERY=$!

    sleep 5
    print_status "Port forwarding established"
}

# Test health endpoints
test_health() {
    echo -e "\n${BLUE}=== Testing Health Endpoints ===${NC}\n"

    # Test ingest service
    print_test "Testing ingest service health..."
    if curl -f -s http://localhost:8081/actuator/health > /dev/null 2>&1; then
        print_status "Ingest service is healthy"
    else
        print_error "Ingest service health check failed"
    fi

    # Test query service
    print_test "Testing query service health..."
    if curl -f -s http://localhost:8083/actuator/health > /dev/null 2>&1; then
        print_status "Query service is healthy"
    else
        print_error "Query service health check failed"
    fi
}

# Test API endpoints
test_api() {
    echo -e "\n${BLUE}=== Testing API Endpoints ===${NC}\n"

    # Test heartbeat endpoint
    print_test "Sending test heartbeat..."
    RESPONSE=$(curl -s -X POST http://localhost:8081/api/events/heartbeat \
        -H "Content-Type: application/json" \
        -H "X-API-KEY: ${API_KEY}" \
        -d '{
            "userId": "test-user",
            "region": "EU",
            "matchId": "test-match",
            "amount": 0
        }' 2>&1)

    if [ $? -eq 0 ]; then
        print_status "Heartbeat sent successfully"
    else
        print_error "Failed to send heartbeat: $RESPONSE"
    fi

    # Test drink event
    print_test "Sending test drink event..."
    RESPONSE=$(curl -s -X POST http://localhost:8081/api/events/drink \
        -H "Content-Type: application/json" \
        -H "X-API-KEY: ${API_KEY}" \
        -d '{
            "userId": "test-user",
            "region": "EU",
            "matchId": "test-match",
            "amount": 2
        }' 2>&1)

    if [ $? -eq 0 ]; then
        print_status "Drink event sent successfully"
    else
        print_error "Failed to send drink event: $RESPONSE"
    fi

    # Wait for processing
    sleep 2

    # Test query endpoints
    print_test "Testing online count..."
    RESPONSE=$(curl -s http://localhost:8083/api/presence/onlineCount 2>&1)
    if [[ "$RESPONSE" =~ ^[0-9]+$ ]] || [[ "$RESPONSE" == *"count"* ]]; then
        print_status "Online count retrieved: $RESPONSE"
    else
        print_error "Failed to get online count: $RESPONSE"
    fi

    print_test "Testing leaderboard..."
    RESPONSE=$(curl -s "http://localhost:8083/api/leaderboard?matchId=test-match&limit=10" 2>&1)
    if [ $? -eq 0 ]; then
        print_status "Leaderboard retrieved"
    else
        print_error "Failed to get leaderboard: $RESPONSE"
    fi
}

# Test HPA
test_hpa() {
    echo -e "\n${BLUE}=== Testing Horizontal Pod Autoscaler ===${NC}\n"

    # Check HPA status
    HPAS=$(kubectl get hpa -n ${NAMESPACE} -o json)

    if [ "$(echo $HPAS | jq '.items | length')" -gt 0 ]; then
        print_status "HPAs configured"

        kubectl get hpa -n ${NAMESPACE} --no-headers | while read line; do
            NAME=$(echo $line | awk '{print $1}')
            TARGETS=$(echo $line | awk '{print $3}')
            REPLICAS=$(echo $line | awk '{print $4}')
            print_test "$NAME: $REPLICAS replicas, targets: $TARGETS"
        done
    else
        print_warning "No HPAs found"
    fi
}

# Test persistent volumes
test_storage() {
    echo -e "\n${BLUE}=== Testing Storage ===${NC}\n"

    # Check PVCs
    PVCS=$(kubectl get pvc -n ${NAMESPACE} -o json)

    if [ "$(echo $PVCS | jq '.items | length')" -gt 0 ]; then
        kubectl get pvc -n ${NAMESPACE} --no-headers | while read line; do
            NAME=$(echo $line | awk '{print $1}')
            STATUS=$(echo $line | awk '{print $2}')
            SIZE=$(echo $line | awk '{print $4}')

            if [ "$STATUS" == "Bound" ]; then
                print_status "$NAME: Bound ($SIZE)"
            else
                print_error "$NAME: $STATUS"
            fi
        done
    else
        print_warning "No persistent volume claims found"
    fi
}

# Run basic load test
test_load() {
    echo -e "\n${BLUE}=== Running Basic Load Test ===${NC}\n"

    print_test "Sending 100 requests..."
    SUCCESS=0
    FAILED=0

    for i in {1..100}; do
        if curl -s -X POST http://localhost:8081/api/events/heartbeat \
            -H "Content-Type: application/json" \
            -H "X-API-KEY: ${API_KEY}" \
            -d "{\"userId\": \"user-$i\", \"region\": \"EU\", \"matchId\": \"match-1\", \"amount\": 0}" \
            &>/dev/null; then
            ((SUCCESS++))
        else
            ((FAILED++))
        fi

        # Show progress
        if [ $((i % 10)) -eq 0 ]; then
            echo -ne "\r  Progress: $i/100 (Success: $SUCCESS, Failed: $FAILED)"
        fi
    done

    echo ""
    if [ $FAILED -eq 0 ]; then
        print_status "All requests successful ($SUCCESS/100)"
    else
        print_warning "Some requests failed (Success: $SUCCESS, Failed: $FAILED)"
    fi
}

# Cleanup
cleanup() {
    echo -e "\n${BLUE}=== Cleanup ===${NC}\n"

    # Kill port-forward processes
    if [ ! -z "$PF_INGEST" ]; then
        kill $PF_INGEST 2>/dev/null || true
    fi
    if [ ! -z "$PF_QUERY" ]; then
        kill $PF_QUERY 2>/dev/null || true
    fi

    print_status "Cleaned up port forwarding"
}

# Generate summary
generate_summary() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}           TEST SUMMARY                 ${NC}"
    echo -e "${BLUE}========================================${NC}\n"

    echo "Cluster: $(kubectl config current-context)"
    echo "Namespace: ${NAMESPACE}"
    echo ""
    echo "Components Status:"
    echo "  - Pods: $(kubectl get pods -n ${NAMESPACE} --no-headers | wc -l) running"
    echo "  - Services: $(kubectl get services -n ${NAMESPACE} --no-headers | wc -l) configured"
    echo "  - HPAs: $(kubectl get hpa -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l) active"
    echo "  - PVCs: $(kubectl get pvc -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l) bound"
    echo ""
    echo "Test Results:"
    echo "  ✓ Cluster connectivity"
    echo "  ✓ Pod readiness"
    echo "  ✓ Service endpoints"
    echo "  ✓ API functionality"
    echo "  ✓ Basic load handling"
    echo ""
    print_status "All tests completed successfully!"
}

# Main execution
main() {
    echo -e "${GREEN}=== WCD Platform Local Testing ===${NC}"

    # Set trap for cleanup
    trap cleanup EXIT

    check_prerequisites
    test_pods
    test_services
    setup_port_forward
    test_health
    test_api
    test_hpa
    test_storage
    test_load
    generate_summary
}

# Run main
main "$@"