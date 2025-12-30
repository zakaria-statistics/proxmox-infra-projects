# Kubernetes Platform Setup

Complete scripts and documentation for deploying a production-grade Kubernetes cluster on Proxmox.

## Quick Start

1. **Read the implementation guide:**
   ```bash
   cat IMPLEMENTATION-GUIDE.md
   ```

2. **Follow the scripts in order:**
   ```bash
   # On Proxmox host:
   ./scripts/01-create-vms.sh

   # On ALL VMs (after OS installation):
   ./scripts/02-prepare-os.sh
   ./scripts/03-install-kubernetes.sh

   # On control plane only:
   ./scripts/04-init-control-plane.sh
   ./scripts/06a-install-calico.sh
   ./scripts/05-get-join-command.sh  # Get command for workers

   # On each worker (run the join command from above)

   # Back on control plane:
   ./scripts/06b-install-metallb.sh
   ./scripts/06c-install-ingress.sh
   ./scripts/06d-install-storage.sh
   ./scripts/06e-install-openfaas.sh  # Optional
   ./scripts/07-verify-cluster.sh
   ./scripts/08-deploy-test-app.sh
   ```

## Directory Structure

```
k8s-platform/
├── IMPLEMENTATION-GUIDE.md    # Detailed implementation guide with timeline
├── README.md                  # This file
├── scripts/                   # Executable setup scripts
│   ├── 01-create-vms.sh              # Create VMs on Proxmox
│   ├── 02-prepare-os.sh              # Prepare OS (run on all VMs)
│   ├── 03-install-kubernetes.sh      # Install K8s (run on all VMs)
│   ├── 04-init-control-plane.sh      # Initialize control plane
│   ├── 05-get-join-command.sh        # Get worker join command
│   ├── 06a-install-calico.sh         # Install CNI networking
│   ├── 06b-install-metallb.sh        # Install load balancer
│   ├── 06c-install-ingress.sh        # Install ingress controller
│   ├── 06d-install-storage.sh        # Install storage provisioner
│   ├── 06e-install-openfaas.sh       # Install serverless (optional)
│   ├── 07-verify-cluster.sh          # Verify cluster health
│   └── 08-deploy-test-app.sh         # Deploy test application
├── configs/                   # Configuration templates
│   ├── example-deployment.yaml       # Example deployment
│   ├── example-ingress.yaml          # Example ingress
│   └── example-pvc.yaml              # Example storage claim
└── docs/                      # Documentation
    └── 02-k8s-platform.md            # Original project documentation
```

## Cluster Architecture

```
Control Plane (VM 201)          Worker Nodes
192.168.11.201                  192.168.11.202 & .203
┌──────────────────┐            ┌──────────────────┐
│  kube-apiserver  │            │   Your Pods      │
│  kube-scheduler  │            │                  │
│  controller-mgr  │            │   ┌──────────┐   │
│  etcd            │◄───────────┤   │   Pod    │   │
└──────────────────┘            │   └──────────┘   │
                                └──────────────────┘
```

## Resource Allocation

- **Control Plane**: 2GB RAM, 2 vCPU, 20GB disk
- **Worker 1**: 3GB RAM, 3 vCPU, 40GB disk
- **Worker 2**: 3GB RAM, 3 vCPU, 40GB disk
- **Total**: 8GB RAM, 8 vCPU, 100GB disk

## Network Configuration

- **Node Network**: 192.168.11.0/24
  - Control Plane: 192.168.11.201
  - Worker 1: 192.168.11.202
  - Worker 2: 192.168.11.203
- **Pod Network**: 10.244.0.0/16 (Calico)
- **Service Network**: 10.96.0.0/12 (default)
- **MetalLB Pool**: 192.168.11.240-250

## Key Components

### Core
- **Kubernetes**: v1.28 (LTS)
- **Container Runtime**: containerd
- **CNI**: Calico v3.26

### Add-ons
- **MetalLB**: Bare-metal load balancer
- **Ingress NGINX**: HTTP/HTTPS routing
- **local-path-provisioner**: Dynamic storage
- **OpenFaaS**: Serverless functions (optional)

## Common Commands

### Cluster Management
```bash
# View cluster info
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces

# View resource usage
kubectl top nodes
kubectl top pods -A

# View logs
kubectl logs -n kube-system <pod-name>
```

### Deployment
```bash
# Create deployment
kubectl create deployment myapp --image=nginx

# Expose as service
kubectl expose deployment myapp --port=80 --type=LoadBalancer

# Scale deployment
kubectl scale deployment myapp --replicas=3

# Update image
kubectl set image deployment/myapp nginx=nginx:1.25
```

### Troubleshooting
```bash
# Check pod details
kubectl describe pod <pod-name>

# Get pod logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Previous instance

# Shell into pod
kubectl exec -it <pod-name> -- bash

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

## Accessing Applications

### Via LoadBalancer
Services with `type: LoadBalancer` get an IP from MetalLB pool:
```bash
kubectl get svc
# Access via EXTERNAL-IP
```

### Via Ingress
HTTP routing based on hostname/path:
```bash
kubectl get ingress
# Add to /etc/hosts: <INGRESS-IP> myapp.local
```

### Via Port Forward
Development access:
```bash
kubectl port-forward svc/myapp 8080:80
# Access via http://localhost:8080
```

## Monitoring

### Check Cluster Health
```bash
./scripts/07-verify-cluster.sh
```

### View Metrics (requires metrics-server)
```bash
kubectl top nodes
kubectl top pods -A
```

### Check Logs
```bash
# System components
kubectl logs -n kube-system -l component=kube-apiserver

# Application logs
kubectl logs -l app=myapp --tail=100 -f
```

## Backup & Recovery

### Backup etcd
```bash
ETCDCTL_API=3 etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Backup Resources
```bash
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml
```

## Upgrade Strategy

1. Backup etcd and cluster configuration
2. Upgrade control plane:
   ```bash
   apt-mark unhold kubeadm
   apt-get update && apt-get install kubeadm=1.29.x-00
   kubeadm upgrade apply v1.29.x
   apt-mark hold kubeadm
   ```
3. Upgrade kubelet and kubectl
4. Repeat for worker nodes

## Security Best Practices

- Enable RBAC (enabled by default)
- Use Network Policies to restrict pod communication
- Regularly update Kubernetes and components
- Use Secrets for sensitive data (consider Sealed Secrets)
- Implement Pod Security Standards
- Scan images for vulnerabilities (Trivy)

## Troubleshooting

### Pods Stuck in Pending
```bash
kubectl describe pod <pod-name>
# Check Events section for scheduling issues
```

### Nodes NotReady
```bash
kubectl describe node <node-name>
journalctl -u kubelet -f
```

### Network Issues
```bash
kubectl get pods -n kube-system  # Check CNI pods
kubectl logs -n kube-system -l k8s-app=calico-node
```

### Storage Issues
```bash
kubectl get pv,pvc
kubectl describe pvc <pvc-name>
kubectl logs -n local-path-storage -l app=local-path-provisioner
```

## Next Steps

1. **Integrate with CI/CD**: Connect GitLab/Jenkins for automated deployments
2. **Set up Monitoring**: Install Prometheus + Grafana
3. **Configure Backups**: Automate etcd backups
4. **Deploy Applications**: Migrate from docker-lxc
5. **Implement GitOps**: Install ArgoCD

## Support

- **Documentation**: See `IMPLEMENTATION-GUIDE.md` for detailed explanations
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **Troubleshooting**: Check logs with `kubectl logs` and `journalctl`

## License

Educational/Personal Use
