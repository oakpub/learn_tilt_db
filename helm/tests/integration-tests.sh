#!/bin/bash

# Integration tests for k8s-helm-tilt-service

set -e

NAMESPACE=${NAMESPACE:-default}
RELEASE_NAME=${RELEASE_NAME:-test-release}
TIMEOUT=${TIMEOUT:-300}

echo "Running integration tests for release: $RELEASE_NAME in namespace: $NAMESPACE"

# Function to wait for deployment to be ready
wait_for_deployment() {
    local deployment=$1
    local timeout=$2
    
    echo "Waiting for deployment $deployment to be ready..."
    kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $NAMESPACE
}

# Function to wait for statefulset to be ready
wait_for_statefulset() {
    local statefulset=$1
    local timeout=$2
    
    echo "Waiting for statefulset $statefulset to be ready..."
    kubectl wait --for=condition=ready --timeout=${timeout}s pod -l app.kubernetes.io/name=$statefulset -n $NAMESPACE
}

# Function to test HTTP endpoint
test_endpoint() {
    local service=$1
    local port=$2
    local path=$3
    local expected_status=$4
    
    echo "Testing endpoint: $service:$port$path"
    
    # Port forward in background
    kubectl port-forward svc/$service $port:80 -n $NAMESPACE &
    local pf_pid=$!
    
    # Wait a bit for port forward to establish
    sleep 5
    
    # Test the endpoint
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port$path || echo "000")
    
    # Kill port forward
    kill $pf_pid 2>/dev/null || true
    
    if [ "$status_code" = "$expected_status" ]; then
        echo "✓ Endpoint test passed: $service:$port$path returned $status_code"
        return 0
    else
        echo "✗ Endpoint test failed: $service:$port$path returned $status_code, expected $expected_status"
        return 1
    fi
}

# Function to check if resource exists
resource_exists() {
    local resource_type=$1
    local resource_name=$2
    
    if kubectl get $resource_type $resource_name -n $NAMESPACE >/dev/null 2>&1; then
        echo "✓ Resource exists: $resource_type/$resource_name"
        return 0
    else
        echo "✗ Resource not found: $resource_type/$resource_name"
        return 1
    fi
}

# Test 1: Check if microservice1 resources exist
echo "Test 1: Checking microservice1 resources..."
if resource_exists deployment microservice1-web && \
   resource_exists service microservice1-web && \
   resource_exists statefulset microservice1-postgres && \
   resource_exists service postgres-service1; then
    echo "✓ All microservice1 resources exist"
else
    echo "✗ Some microservice1 resources are missing"
    exit 1
fi

# Test 2: Check if microservice2 resources exist
echo "Test 2: Checking microservice2 resources..."
if resource_exists deployment microservice2-web && \
   resource_exists service microservice2-web && \
   resource_exists statefulset microservice2-postgres && \
   resource_exists service postgres-service2; then
    echo "✓ All microservice2 resources exist"
else
    echo "✗ Some microservice2 resources are missing"
    exit 1
fi

# Test 3: Wait for deployments to be ready
echo "Test 3: Waiting for deployments to be ready..."
wait_for_deployment microservice1-web $TIMEOUT
wait_for_deployment microservice2-web $TIMEOUT
echo "✓ All deployments are ready"

# Test 4: Wait for statefulsets to be ready
echo "Test 4: Waiting for statefulsets to be ready..."
wait_for_statefulset microservice1-postgres $TIMEOUT
wait_for_statefulset microservice2-postgres $TIMEOUT
echo "✓ All statefulsets are ready"

# Test 5: Test microservice1 health endpoint
echo "Test 5: Testing microservice1 health endpoint..."
test_endpoint microservice1-web 8001 /health 200

# Test 6: Test microservice2 health endpoint
echo "Test 6: Testing microservice2 health endpoint..."
test_endpoint microservice2-web 8002 /health 200

# Test 7: Test microservice1 database status endpoint
echo "Test 7: Testing microservice1 database status endpoint..."
test_endpoint microservice1-web 8001 /db-status 200

# Test 8: Test microservice2 database status endpoint
echo "Test 8: Testing microservice2 database status endpoint..."
test_endpoint microservice2-web 8002 /db-status 200

# Test 9: Test microservice1 API endpoint
echo "Test 9: Testing microservice1 API endpoint..."
test_endpoint microservice1-web 8001 /api/service1 200

# Test 10: Test microservice2 API endpoint
echo "Test 10: Testing microservice2 API endpoint..."
test_endpoint microservice2-web 8002 /api/service2 200

# Test 11: Check database connectivity by examining logs
echo "Test 11: Checking database connectivity in logs..."
if kubectl logs deployment/microservice1-web -n $NAMESPACE --tail=50 | grep -q "Database connection" || \
   kubectl logs deployment/microservice1-web -n $NAMESPACE --tail=50 | grep -q "healthy"; then
    echo "✓ Microservice1 database connectivity confirmed"
else
    echo "⚠ Microservice1 database connectivity unclear from logs"
fi

if kubectl logs deployment/microservice2-web -n $NAMESPACE --tail=50 | grep -q "Database connection" || \
   kubectl logs deployment/microservice2-web -n $NAMESPACE --tail=50 | grep -q "healthy"; then
    echo "✓ Microservice2 database connectivity confirmed"
else
    echo "⚠ Microservice2 database connectivity unclear from logs"
fi

echo ""
echo "All integration tests completed! ✓"
echo ""
echo "Summary:"
echo "- Microservice1 web: http://localhost:8001"
echo "- Microservice2 web: http://localhost:8002"
echo "- Health checks: /health"
echo "- Database status: /db-status"
echo "- API endpoints: /api/service1, /api/service2"