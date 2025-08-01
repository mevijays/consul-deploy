# Consul Service Mesh and API Gateway Deployment

This directory contains all the necessary files to deploy HashiCorp Consul service mesh with API Gateway on your RKE Kubernetes cluster.

## 📁 Directory Structure

```
consul-deployment/
├── scripts/
│   ├── deploy-consul.sh       # Main deployment script
│   └── manage-demo.sh         # Demo application management
├── helm-values/
│   └── consul-values.yaml     # Consul Helm chart values
├── certificates/
│   └── cert-manager-config.yaml # Certificate configuration
├── api-gateway/
│   └── gateway-config.yaml    # API Gateway configuration
├── namespace-and-secrets.yaml # Kubernetes resources
├── demo-app.yaml              # Example service mesh application
└── README.md                  # This file
```

## 🚀 Quick Start

### Prerequisites

1. **RKE Cluster Running** with MetalLB load balancer
2. **kubectl** configured and connected to your cluster
3. **Helm 3.x** installed
4. **cert-manager** (will be installed automatically)

### 1. Deploy Consul Service Mesh

```bash
cd consul-deployment
./scripts/deploy-consul.sh
```

This script will:
- ✅ Install cert-manager (if not present)
- ✅ Create Consul namespace and secrets
- ✅ Deploy Consul with service mesh enabled
- ✅ Configure API Gateway with TLS
- ✅ Set up certificates with cert-manager
- ✅ Configure static LoadBalancer IPs

### 2. Access Consul UI

After deployment, access the Consul UI:
- **URL**: `https://192.168.1.242/ui`
- **Domain**: `https://api.consul.local.domain/ui` (requires DNS/hosts entry)
- **Token**: Retrieved automatically by the script

### 3. Deploy Demo Application (Optional)

```bash
./scripts/manage-demo.sh deploy
./scripts/manage-demo.sh status
./scripts/manage-demo.sh test
```

## 🔧 Configuration Details

### Static IP Assignments

The deployment uses these static IPs (configured in MetalLB):

| Service | IP Address | Purpose |
|---------|------------|---------|
| Consul UI | `192.168.1.240` | Web interface access |
| Mesh Gateway | `192.168.1.241` | Service mesh traffic |
| API Gateway | `192.168.1.242` | External API access |

### Certificates

Two certificate options are configured:

1. **Self-signed** (for development):
   - Issuer: `selfsigned-issuer`
   - Certificate: `consul-api-gateway-selfsigned`
   - Domain: `api.consul.local.domain`

2. **Let's Encrypt** (for production):
   - Issuer: `letsencrypt-prod`
   - Certificate: `consul-api-gateway-tls`
   - Domain: `api.consul.local.domain`

### Service Mesh Features

- ✅ **Automatic sidecar injection** (opt-in via annotations)
- ✅ **mTLS encryption** between services
- ✅ **Service discovery** and health checking
- ✅ **Traffic management** and load balancing
- ✅ **Observability** with metrics and tracing
- ✅ **API Gateway** with TLS termination

## 📊 Monitoring and Observability

### Consul UI Access

```bash
# Get admin token
kubectl get secret consul-bootstrap-acl-token -n consul -o jsonpath='{.data.token}' | base64 -d

# Port forward (alternative access)
kubectl port-forward -n consul svc/consul-ui 8500:80
```

### Service Mesh Status

```bash
# Check Consul cluster members
kubectl exec -n consul deployment/consul-server -- consul members

# List services in service mesh
kubectl exec -n consul deployment/consul-server -- consul catalog services

# Check service mesh configuration
kubectl get servicedefaults -A
kubectl get servicerouter -A
kubectl get serviceresolver -A
```

### API Gateway Status

```bash
# Check gateway status
kubectl get gateway -n consul
kubectl get httproute -n consul

# Check gateway pods
kubectl get pods -n consul -l component=api-gateway
```

## 🔐 Security Configuration

### ACLs (Access Control Lists)

Consul is deployed with ACLs enabled:
- **Bootstrap token**: Automatically generated
- **Default policy**: `deny` (secure by default)
- **Agent tokens**: Automatically configured

### TLS Configuration

- **Internal communication**: mTLS enabled
- **API access**: HTTPS only
- **Certificate management**: Automated with cert-manager

### Network Policies

Consider implementing Kubernetes Network Policies for additional security:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: consul-mesh-policy
  namespace: consul
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: consul
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: consul
```

## 🛠️ Troubleshooting

### Common Issues

1. **Pods not starting**:
   ```bash
   kubectl describe pods -n consul
   kubectl logs -n consul -l app=consul
   ```

2. **Certificate issues**:
   ```bash
   kubectl describe certificate -n consul
   kubectl get certificaterequests -n consul
   ```

3. **Service mesh injection not working**:
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   # Check for connect-inject annotations
   ```

4. **LoadBalancer IP not assigned**:
   ```bash
   kubectl get svc -n consul
   # Check MetalLB configuration
   kubectl logs -n metallb-system -l app=metallb
   ```

### Useful Commands

```bash
# Check all Consul resources
kubectl get all -n consul

# View Consul server logs
kubectl logs -n consul -l app=consul,component=server

# Check connect-inject logs
kubectl logs -n consul -l app=consul-connect-injector

# View API Gateway controller logs
kubectl logs -n consul -l app=consul-api-gateway-controller

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup consul-server.consul.svc.cluster.local
```

## 🔄 Updates and Maintenance

### Upgrading Consul

```bash
# Update Helm repository
helm repo update

# Upgrade Consul
helm upgrade consul hashicorp/consul \
    --namespace consul \
    --values helm-values/consul-values.yaml \
    --version "1.3.0"
```

### Backup and Restore

```bash
# Create snapshot
kubectl exec -n consul deployment/consul-server -- consul snapshot save backup.snap

# Restore snapshot
kubectl exec -n consul deployment/consul-server -- consul snapshot restore backup.snap
```

## 🔗 Integration Examples

### Service Mesh Application Template

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/connect-service-upstreams: "backend:9090,database:5432"
    spec:
      containers:
      - name: app
        image: my-app:latest
        ports:
        - containerPort: 8080
```

### Ingress through API Gateway

```yaml
apiVersion: gateway.consul.io/v1beta1
kind: HTTPRoute
metadata:
  name: my-app-route
spec:
  parentRefs:
    - name: consul-api-gateway
      namespace: consul
  hostnames:
    - "my-app.consul.local.domain"
  rules:
    - backendRefs:
        - name: my-app-service
          port: 80
```

## 📞 Support

For issues and questions:
1. Check the [Consul documentation](https://www.consul.io/docs)
2. Review [Consul on Kubernetes guide](https://www.consul.io/docs/k8s)
3. Check [API Gateway documentation](https://www.consul.io/docs/api-gateway)

## 🎯 Next Steps

After successful deployment:

1. **Configure DNS** to point `api.consul.local.domain` to `192.168.1.242`
2. **Deploy your applications** with service mesh annotations
3. **Set up monitoring** with Prometheus and Grafana
4. **Configure traffic policies** for advanced routing
5. **Implement security policies** for service-to-service communication
