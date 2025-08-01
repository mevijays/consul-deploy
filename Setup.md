## install on rke consul
- Make rke up with cluster.yml
```bash
rke up --ignore-docker-version
cp kube_config_cluster.yml ~/.kube/config # to use kubectl and default kubeconfig
```
- Install cert manager and metalLB
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
# deploy metallb ippool and L2advertisment
kubectl apply -f metallb/apply.yaml
```
- Deploy storage
```bash
cd consul-deployment
kubectl apply -f storage/local-path-provisioner.yaml
```
- Create required CA certs and issuers in cert-manager
```bash
kubectl apply -f certificates/cert-manager-config.yaml
# validate status of cert and issuers
kubectl get clusterissuer
kubectl get cert -A
kubectl get secret -n cert-manager
kubectl get secret -n consul
```
- Copy the cert secret to consul namespace **This is required for S2S TLS with own CA and it is a must of the secition in consul values file reference ca cert and key**
```bash
kubectl get secret ca-key-pair -n cert-manager -o yaml  | sed 's/namespace: cert-manager/namespace: consul/' | kubectl apply -f -
```
- Run the helm install for consul
```bash
helm upgrade --install consul hashicorp/consul --values helm-values/consul-values.yaml -n consul
```
- Create a certificate for api gateway. **note** you can add virtualhost names domain like i did.
```bash
kubectl apply -f certificates/api-gateway-cert.yaml 
# validate for ready status as true
kubectl get cert -n consul  
```
- Setup API gateway now *note* gatewayclass will be created automatically after consul installation. Api gateway uses this class in config.
```bash
kubectl apply -f api-gateway/gateway-config.yaml   
```
- Setup proxy defaults now for global or namespaced 
```bash
kubectl apply -f service-mesh/proxy-defaults.yaml  
```

## Deploy application
- demo1
```bash
kubectl apply -f demo-apps/demo-app-with-mesh.yaml 
kubectl apply -f demo-apps/demo2-app-with-mesh.yaml
```
Above will create 2 namespaces and deploy 2 application in each will create httproute and intentions for them. These two will have two hostnames pointing to same api gateway.

## Traffic Flow Diagram

```
           +-------------------+
           |      User         |
           +-------------------+
                    |
                    v
           +---------------------------+
           |   Consul API Gateway      |
           |  (api.consul.local.domain |
           |   apps.consul.local.domain)|
           +---------------------------+
                |                 |
                |                 |
         +------+                 +------+
         |                             |
         v                             v
+-------------------+         +-------------------+
|  demo1 Namespace  |         |  demo2 Namespace  |
|  (httproute:      |         |  (httproute:      |
|   api.consul...)  |         |   apps.consul...) |
|   +-----------+   |         |   +-----------+   |
|   | demo-app  |   |         |   | demo2-app |   |
|   +-----------+   |         |   +-----------+   |
+-------------------+         +-------------------+
```

- User traffic for two hostnames (api.consul.local.domain and apps.consul.local.domain) is routed to the Consul API Gateway.
- The API Gateway uses HTTPRoute resources to direct traffic to demo1 and demo2 applications in their respective namespaces.


