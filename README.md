# RKE Cluster Setup with Ansible

This repository contains Ansible playbooks and configuration files to prepare hosts for RKE (Rancher Kubernetes Engine) installation.

## Files Structure

- `playbook.yaml` - Main Ansible playbook for host preparation
- `inventory.ini` - Ansible inventory with 1 master and 2 worker nodes
- `ansible.cfg` - Ansible configuration (handles SSH settings automatically)
- `cluster.yml` - RKE cluster configuration template
- `create-proxmox-vm.sh` - Script to create Proxmox VMs

## Prerequisites

1. Ansible installed on control machine
2. SSH access to target hosts
3. Target hosts running Ubuntu 22.04/24.04

## Quick Start

### 1. Update IP Addresses
Edit `inventory.ini` and `cluster.yml` with your actual IP addresses:
```
rke-master-1: 192.168.1.221
rke-worker-1: 192.168.1.222  
rke-worker-2: 192.168.1.223
```

### 2. Run the Ansible Playbook
```bash
# Test connectivity
ansible all -m ping

# Run the full playbook
ansible-playbook playbook.yaml

# Run with verbose output
ansible-playbook playbook.yaml -v
```

### 3. Install RKE
```bash
# Download RKE binary
wget https://github.com/rancher/rke/releases/latest/download/rke_linux-amd64
chmod +x rke_linux-amd64
sudo mv rke_linux-amd64 /usr/local/bin/rke

# Create the cluster
rke up --config cluster.yml
```

### 4. Access the Cluster
```bash
# Copy kubeconfig
mkdir -p ~/.kube
cp kube_config_cluster.yml ~/.kube/config

# Verify cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

## What the Playbook Does

### Package Installation
- ✅ Docker CE (latest stable)
- ✅ QEMU Guest Agent (for Proxmox integration)
- ✅ Essential tools (vim, wget, curl, net-tools)

### System Configuration
- ✅ Disable swap (required for Kubernetes)
- ✅ Load kernel modules (br_netfilter, overlay)
- ✅ Configure sysctl parameters for Kubernetes
- ✅ Configure Docker daemon with proper settings

### User Setup
- ✅ Add user to docker group
- ✅ Create /opt/rke directory
- ✅ Automatic SSH host key acceptance

### Service Management
- ✅ Start and enable Docker
- ✅ Start and enable QEMU Guest Agent
- ✅ Verify installations

## SSH Configuration

The playbook automatically handles SSH host keys by:
- Using `StrictHostKeyChecking=no`
- Using `UserKnownHostsFile=/dev/null`
- Configured in both `ansible.cfg` and inventory

## Troubleshooting

### Check Docker
```bash
ansible all -m shell -a "docker --version"
ansible all -m shell -a "systemctl status docker"
```

### Check QEMU Guest Agent
```bash
ansible all -m shell -a "systemctl status qemu-guest-agent"
```

### Test Docker Functionality
```bash
ansible all -m shell -a "docker run --rm hello-world" -b --become-user=vijay
```

### Check System Readiness
```bash
ansible all -m shell -a "swapon --show"  # Should be empty
ansible all -m shell -a "lsmod | grep br_netfilter"
```

## Security Notes

- Default credentials are set for lab environment
- Change passwords in production
- Consider using SSH keys instead of passwords
- Update firewall rules as needed

## Next Steps

After running the playbook:
1. Install RKE binary
2. Customize `cluster.yml` for your environment
3. Run `rke up` to create the cluster
4. Install kubectl and access your cluster
