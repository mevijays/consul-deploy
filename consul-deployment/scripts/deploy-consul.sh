#!/bin/bash

# Consul Service Mesh and API Gateway Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONSUL_NAMESPACE="consul"
CONSUL_DOMAIN="api.consul.local.domain"
STATIC_IP="192.168.1.242"
HELM_RELEASE_NAME="consul"

echo -e "${BLUE}=== Consul Service Mesh and API Gateway Deployment ===${NC}"

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        exit 1
    fi
}

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    
    echo -e "${YELLOW}Waiting for deployment $deployment in namespace $namespace...${NC}"
    kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace
}

# Function to wait for pods
wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}
    
    echo -e "${YELLOW}Waiting for pods with label $label in namespace $namespace...${NC}"
    kubectl wait --for=condition=ready --timeout=${timeout}s pod -l $label -n $namespace
}

echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"
check_command kubectl
check_command helm

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

# Check required files exist
required_files=(
    "helm-values/consul-values.yaml"
    "certificates/cert-manager-config.yaml"
    "namespace-and-secrets.yaml"
    "api-gateway/gateway-config.yaml"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: Required file $file not found${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✓ Prerequisites check passed${NC}"

echo -e "${BLUE}Step 2: Adding Helm repositories...${NC}"
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add jetstack https://charts.jetstack.io
helm repo update

echo -e "${GREEN}✓ Helm repositories added${NC}"

echo -e "${BLUE}Step 3: Installing cert-manager...${NC}"
# Check if cert-manager is already installed
if ! kubectl get namespace cert-manager &> /dev/null; then
    kubectl create namespace cert-manager
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.13.0 \
        --set installCRDs=true \
        --wait
    echo -e "${GREEN}✓ cert-manager installed${NC}"
else
    echo -e "${YELLOW}cert-manager already exists${NC}"
fi

# Wait for cert-manager to be ready
wait_for_deployment cert-manager cert-manager
wait_for_deployment cert-manager cert-manager-cainjector
wait_for_deployment cert-manager cert-manager-webhook

echo -e "${BLUE}Step 4: Checking storage class...${NC}"
if ! kubectl get storageclass | grep -q "(default)"; then
    echo -e "${YELLOW}No default storage class found. Installing local-path-provisioner...${NC}"
    if [ ! -f "storage/local-path-provisioner.yaml" ]; then
        echo -e "${RED}Error: storage/local-path-provisioner.yaml not found${NC}"
        echo -e "${YELLOW}Please ensure you have the storage configuration file${NC}"
        exit 1
    fi
    kubectl apply -f storage/local-path-provisioner.yaml
    echo -e "${YELLOW}Waiting for local-path-provisioner to be ready...${NC}"
    kubectl wait --for=condition=available --timeout=120s deployment/local-path-provisioner -n local-path-storage
    echo -e "${GREEN}✓ Local path provisioner installed${NC}"
else
    echo -e "${GREEN}✓ Storage class available${NC}"
fi

echo -e "${BLUE}Step 5: Configuring certificates for local lab...${NC}"
kubectl create namespace $CONSUL_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f certificates/cert-manager-config.yaml
# Install MetalLB if not present
if ! kubectl get namespace metallb-system &> /dev/null; then
    echo -e "${YELLOW}Installing MetalLB...${NC}"
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
    
    # Wait for MetalLB to be ready
    echo -e "${YELLOW}Waiting for MetalLB components to be ready...${NC}"
    kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=app=metallb \
        --timeout=300s
    
    echo -e "${GREEN}✓ MetalLB installed successfully${NC}"
else
    echo -e "${YELLOW}MetalLB is already installed${NC}"
fi

# Apply MetalLB configuration
echo -e "${YELLOW}Applying MetalLB configuration...${NC}"
kubectl apply -f ../metallb/apply.yaml

# Wait for CA certificate to be ready first
echo -e "${YELLOW}Waiting for CA certificate to be issued...${NC}"
kubectl wait --for=condition=ready certificate/selfsigned-ca -n cert-manager --timeout=300s

echo -e "${GREEN}✓ Self-signed certificates configured for local lab${NC}"

echo -e "${BLUE}Step 6: Creating namespace and secrets...${NC}"
kubectl apply -f namespace-and-secrets.yaml

# Copy CA certificate and key from cert-manager to consul namespace
echo -e "${YELLOW}Copying CA certificates to consul namespace...${NC}"
kubectl get secret ca-key-pair -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ca.crt
kubectl get secret ca-key-pair -n cert-manager -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/ca.key

# Delete existing empty secrets if they exist
kubectl delete secret consul-ca-cert consul-ca-key -n $CONSUL_NAMESPACE 2>/dev/null || true

# Create proper CA secrets
kubectl create secret generic consul-ca-cert -n $CONSUL_NAMESPACE --from-file=tls.crt=/tmp/ca.crt
kubectl create secret generic consul-ca-key -n $CONSUL_NAMESPACE --from-file=tls.key=/tmp/ca.key

# Clean up temp files
rm -f /tmp/ca.crt /tmp/ca.key

echo -e "${GREEN}✓ Namespace and secrets created${NC}"

echo -e "${BLUE}Step 7: Generating Consul gossip encryption key...${NC}"
# Generate a proper gossip encryption key
GOSSIP_KEY=$(kubectl exec -n $CONSUL_NAMESPACE -it deployment/consul-server -- consul keygen 2>/dev/null || openssl rand -base64 32)
kubectl patch secret consul-gossip-encryption-key -n $CONSUL_NAMESPACE \
    --type='json' \
    -p="[{'op': 'replace', 'path': '/data/key', 'value': '$(echo -n $GOSSIP_KEY | base64 -w 0)'}]" || true

echo -e "${GREEN}✓ Gossip encryption key generated${NC}"

echo -e "${BLUE}Step 8: Installing Consul with Helm...${NC}"
helm upgrade --install $HELM_RELEASE_NAME hashicorp/consul \
    --namespace $CONSUL_NAMESPACE \
    --values helm-values/consul-values.yaml \
    --version "1.3.0" \
    --wait \
    --timeout 10m

echo -e "${GREEN}✓ Consul installed${NC}"

echo -e "${BLUE}Step 9: Waiting for Consul components to be ready...${NC}"
# Wait for server
echo -e "${YELLOW}Waiting for Consul servers to be ready...${NC}"
kubectl wait --for=condition=ready --timeout=600s pod -l app=consul,component=server -n $CONSUL_NAMESPACE

# Wait for connect-injector
echo -e "${YELLOW}Waiting for Connect Injector to be ready...${NC}"
wait_for_deployment $CONSUL_NAMESPACE consul-consul-connect-injector

# Check if clients are enabled and wait for them
if kubectl get daemonset -n $CONSUL_NAMESPACE | grep -q consul-client; then
    echo -e "${YELLOW}Waiting for Consul clients to be ready...${NC}"
    kubectl wait --for=condition=ready --timeout=300s pod -l app=consul,component=client -n $CONSUL_NAMESPACE
fi

echo -e "${GREEN}✓ Consul components are ready${NC}"

echo -e "${BLUE}Step 10: Deploying API Gateway...${NC}"
kubectl apply -f api-gateway/gateway-config.yaml

echo -e "${GREEN}✓ API Gateway deployed${NC}"

echo -e "${BLUE}Step 11: Verifying deployment...${NC}"

# Get service information
echo -e "${YELLOW}Consul Services:${NC}"
kubectl get svc -n $CONSUL_NAMESPACE

echo -e "${YELLOW}Consul Pods:${NC}"
kubectl get pods -n $CONSUL_NAMESPACE

echo -e "${YELLOW}API Gateway:${NC}"
kubectl get gateway -n $CONSUL_NAMESPACE

echo -e "${YELLOW}HTTPRoutes:${NC}"
kubectl get httproute -n $CONSUL_NAMESPACE

echo -e "${YELLOW}Certificates:${NC}"
kubectl get certificate -n $CONSUL_NAMESPACE

echo -e "${GREEN}=== Deployment Complete! ===${NC}"

echo -e "${BLUE}Access Information:${NC}"
echo -e "Consul UI: https://$STATIC_IP/ui"
echo -e "Consul API: https://$STATIC_IP/v1"
echo -e "Domain: https://$CONSUL_DOMAIN"
echo -e ""
echo -e "${BLUE}Admin Token (for UI access):${NC}"
kubectl get secret consul-bootstrap-acl-token -n $CONSUL_NAMESPACE -o jsonpath='{.data.token}' | base64 -d
echo -e ""
echo -e ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. Update your DNS or /etc/hosts to point $CONSUL_DOMAIN to $STATIC_IP"
echo -e "2. Access Consul UI at https://$CONSUL_DOMAIN/ui"
echo -e "3. Use the admin token above for authentication"
echo -e "4. Configure your applications for service mesh injection"
echo -e ""
echo -e "${BLUE}Useful Commands:${NC}"
echo -e "kubectl get all -n $CONSUL_NAMESPACE"
echo -e "kubectl logs -n $CONSUL_NAMESPACE -l app=consul"
echo -e "kubectl port-forward -n $CONSUL_NAMESPACE svc/consul-ui 8500:80"
