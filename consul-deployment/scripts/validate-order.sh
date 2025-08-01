#!/bin/bash

# Consul Deployment Order Validation Script
echo "=== Consul Deployment Order Review ==="
echo
echo "Correct Deployment Order:"
echo "1. Prerequisites check (kubectl, helm, files)"
echo "2. Helm repositories (hashicorp, jetstack)"
echo "3. cert-manager installation"
echo "4. Storage class verification/installation"
echo "5. Certificate configuration (cert-manager-config.yaml)"
echo "6. Namespace and secrets creation"
echo "7. CA certificate copying from cert-manager to consul namespace"
echo "8. Gossip encryption key generation"
echo "9. Consul Helm installation"
echo "10. Wait for Consul components (servers, connect-injector)"
echo "11. API Gateway deployment"
echo "12. Verification and status check"
echo
echo "Key Dependencies:"
echo "- cert-manager must be ready before certificate configuration"
echo "- CA certificates must exist before Consul starts"
echo "- Storage class must exist before Consul StatefulSet"
echo "- Consul must be ready before API Gateway"
echo
echo "Files Required:"
echo "- helm-values/consul-values.yaml"
echo "- certificates/cert-manager-config.yaml" 
echo "- namespace-and-secrets.yaml"
echo "- api-gateway/gateway-config.yaml"
echo "- storage/local-path-provisioner.yaml (if no default storage class)"
echo
