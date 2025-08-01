#!/bin/bash

# Demo Application Management Script for Consul Service Mesh
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DEMO_NAMESPACE="demo-apps"

echo -e "${BLUE}=== Consul Service Mesh Demo Application ===${NC}"

show_help() {
    echo "Usage: $0 [deploy|delete|status|test]"
    echo ""
    echo "Commands:"
    echo "  deploy  - Deploy the demo application"
    echo "  delete  - Delete the demo application"
    echo "  status  - Show application status"
    echo "  test    - Test the service mesh connectivity"
    echo "  help    - Show this help message"
}

deploy_demo() {
    echo -e "${BLUE}Deploying demo application...${NC}"
    
    kubectl apply -f demo-app.yaml
    
    echo -e "${YELLOW}Waiting for demo application to be ready...${NC}"
    kubectl wait --for=condition=available --timeout=300s deployment/frontend -n $DEMO_NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/backend -n $DEMO_NAMESPACE
    
    echo -e "${GREEN}✓ Demo application deployed successfully${NC}"
    show_status
}

delete_demo() {
    echo -e "${BLUE}Deleting demo application...${NC}"
    kubectl delete -f demo-app.yaml --ignore-not-found=true
    echo -e "${GREEN}✓ Demo application deleted${NC}"
}

show_status() {
    echo -e "${BLUE}Demo Application Status:${NC}"
    echo -e "${YELLOW}Namespaces:${NC}"
    kubectl get namespace $DEMO_NAMESPACE 2>/dev/null || echo "Demo namespace not found"
    
    echo -e "${YELLOW}Deployments:${NC}"
    kubectl get deployments -n $DEMO_NAMESPACE 2>/dev/null || echo "No deployments found"
    
    echo -e "${YELLOW}Services:${NC}"
    kubectl get services -n $DEMO_NAMESPACE 2>/dev/null || echo "No services found"
    
    echo -e "${YELLOW}Pods:${NC}"
    kubectl get pods -n $DEMO_NAMESPACE 2>/dev/null || echo "No pods found"
    
    echo -e "${YELLOW}HTTPRoutes:${NC}"
    kubectl get httproute -n $DEMO_NAMESPACE 2>/dev/null || echo "No HTTPRoutes found"
    
    echo -e "${YELLOW}Service Mesh Status:${NC}"
    kubectl get servicedefaults -n $DEMO_NAMESPACE 2>/dev/null || echo "No ServiceDefaults found"
}

test_connectivity() {
    echo -e "${BLUE}Testing service mesh connectivity...${NC}"
    
    # Check if pods are running
    if ! kubectl get pods -n $DEMO_NAMESPACE | grep -q Running; then
        echo -e "${RED}Error: Demo application pods are not running${NC}"
        return 1
    fi
    
    # Get frontend pod
    FRONTEND_POD=$(kubectl get pods -n $DEMO_NAMESPACE -l app=frontend -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$FRONTEND_POD" ]; then
        echo -e "${RED}Error: Frontend pod not found${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Testing frontend to backend connectivity...${NC}"
    
    # Test connectivity through service mesh
    kubectl exec -n $DEMO_NAMESPACE $FRONTEND_POD -c frontend -- curl -s http://127.0.0.1:9090/status/200 || {
        echo -e "${RED}Error: Service mesh connectivity test failed${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ Service mesh connectivity test passed${NC}"
    
    # Show Envoy proxy status
    echo -e "${YELLOW}Envoy proxy status:${NC}"
    kubectl exec -n $DEMO_NAMESPACE $FRONTEND_POD -c consul-connect-envoy-sidecar -- curl -s http://127.0.0.1:19000/ready || true
    
    # Show service mesh traffic
    echo -e "${YELLOW}Current service registrations in Consul:${NC}"
    kubectl exec -n consul deployment/consul-server -- consul catalog services
}

# Main script logic
case "${1:-help}" in
    deploy)
        deploy_demo
        ;;
    delete)
        delete_demo
        ;;
    status)
        show_status
        ;;
    test)
        test_connectivity
        ;;
    help|*)
        show_help
        ;;
esac
