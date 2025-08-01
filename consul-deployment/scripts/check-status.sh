#!/bin/bash

echo "=== Consul Deployment Status Monitor ==="
echo
echo "Storage Classes:"
kubectl get storageclass
echo
echo "Consul Namespace Pods:"
kubectl get pods -n consul -o wide
echo
echo "Consul Persistent Volume Claims:"
kubectl get pvc -n consul
echo
echo "Consul Services:"
kubectl get svc -n consul
echo
echo "Consul StatefulSet Status:"
kubectl get sts -n consul
echo
