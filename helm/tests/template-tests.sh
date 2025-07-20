#!/bin/bash

# Helm template tests for k8s-helm-tilt-service

set -e

CHART_DIR="./helm"
TEST_DIR="./helm/tests"

echo "Running Helm template tests..."

# Test 1: Lint the chart
echo "Test 1: Linting Helm chart..."
helm lint $CHART_DIR
echo "✓ Helm lint passed"

# Test 2: Template with default values
echo "Test 2: Templating with default values..."
helm template test-release $CHART_DIR > /tmp/default-template.yaml
echo "✓ Default template generation passed"

# Test 3: Template with dev values
echo "Test 3: Templating with dev values..."
helm template test-release $CHART_DIR -f ./environments/dev-values.yaml > /tmp/dev-template.yaml
echo "✓ Dev template generation passed"

# Test 4: Template with service1-only values
echo "Test 4: Templating with service1-only values..."
helm template test-release $CHART_DIR -f ./environments/service1-only-values.yaml > /tmp/service1-template.yaml
echo "✓ Service1-only template generation passed"

# Test 5: Template with service2-only values
echo "Test 5: Templating with service2-only values..."
helm template test-release $CHART_DIR -f ./environments/service2-only-values.yaml > /tmp/service2-template.yaml
echo "✓ Service2-only template generation passed"

# Test 6: Template with test values (no persistence)
echo "Test 6: Templating with test values..."
helm template test-release $CHART_DIR -f ./environments/test-values.yaml > /tmp/test-template.yaml
echo "✓ Test template generation passed"

# Test 7: Check that microservice1 resources are present in default template
echo "Test 7: Checking microservice1 resources in default template..."
if grep -q "microservice1-web" /tmp/default-template.yaml; then
    echo "✓ Microservice1 web resources found"
else
    echo "✗ Microservice1 web resources not found"
    exit 1
fi

if grep -q "microservice1-postgres" /tmp/default-template.yaml; then
    echo "✓ Microservice1 postgres resources found"
else
    echo "✗ Microservice1 postgres resources not found"
    exit 1
fi

# Test 8: Check that microservice2 resources are present in default template
echo "Test 8: Checking microservice2 resources in default template..."
if grep -q "microservice2-web" /tmp/default-template.yaml; then
    echo "✓ Microservice2 web resources found"
else
    echo "✗ Microservice2 web resources not found"
    exit 1
fi

if grep -q "microservice2-postgres" /tmp/default-template.yaml; then
    echo "✓ Microservice2 postgres resources found"
else
    echo "✗ Microservice2 postgres resources not found"
    exit 1
fi

# Test 9: Check that PVC is created when persistence is enabled
echo "Test 9: Checking PVC creation with persistence enabled..."
if grep -q "PersistentVolumeClaim" /tmp/dev-template.yaml; then
    echo "✓ PersistentVolumeClaim found in dev template"
else
    echo "✗ PersistentVolumeClaim not found in dev template"
    exit 1
fi

# Test 10: Check that PVC is not created when persistence is disabled
echo "Test 10: Checking PVC absence with persistence disabled..."
if grep -q "PersistentVolumeClaim" /tmp/test-template.yaml; then
    echo "✗ PersistentVolumeClaim found in test template (should not be present)"
    exit 1
else
    echo "✓ PersistentVolumeClaim correctly absent in test template"
fi

# Test 11: Check that only microservice1 resources are present in service1-only template
echo "Test 11: Checking service1-only template..."
if grep -q "microservice1-web" /tmp/service1-template.yaml && ! grep -q "microservice2-web" /tmp/service1-template.yaml; then
    echo "✓ Service1-only template contains only microservice1 resources"
else
    echo "✗ Service1-only template validation failed"
    exit 1
fi

# Test 12: Check that only microservice2 resources are present in service2-only template
echo "Test 12: Checking service2-only template..."
if grep -q "microservice2-web" /tmp/service2-template.yaml && ! grep -q "microservice1-web" /tmp/service2-template.yaml; then
    echo "✓ Service2-only template contains only microservice2 resources"
else
    echo "✗ Service2-only template validation failed"
    exit 1
fi

echo ""
echo "All Helm template tests passed! ✓"

# Cleanup
rm -f /tmp/*-template.yaml