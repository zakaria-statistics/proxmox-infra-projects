# Kubernetes Platform (Runtime Tier)

## Overview

Production-grade Kubernetes cluster for container orchestration, microservices deployment, and serverless function execution.

## Infrastructure Type

**Virtual Machines** - Kubernetes requires full kernel control for cgroups, namespaces, and kernel modules

## Cluster Architecture

- **1 Control Plane Node** - API server, scheduler, controller manager, etcd
- **2 Worker Nodes** - Application workload execution

## Resource Allocation

### Total Cluster Resources
- **RAM:** 6-8GB total
- **vCPU:** 8 cores total
- **Storage:** 100GB+ (persistent volumes)

### Per-Node Breakdown

**Control Plane:**
- RAM: 2GB
- vCPU: 2 cores
- Storage: 20GB

**Worker Nodes (each):**
- RAM: 2-3GB
- vCPU: 3 cores
- Storage: 40GB

## Key Components

### Core Kubernetes
- **kubeadm** - Cluster bootstrapping
- **kubelet** - Node agent
- **containerd** - Container runtime
- **kube-proxy** - Network proxy
- **CoreDNS** - Service discovery

### Networking
- **Calico** or **Flannel** - CNI plugin
- **MetalLB** - Bare-metal load balancer
- **Ingress NGINX** - HTTP/HTTPS routing

### Serverless Runtime
- **OpenFaaS** - Function-as-a-Service platform
- **Knative** - Alternative serverless framework

### Storage
- **Local Path Provisioner** or **Longhorn** - Persistent volumes
- **NFS Client Provisioner** - Shared storage

## Implementation Steps

### 1. Create VMs on Proxmox

```bash
# Control Plane VM
qm create 201 --name k8s-control --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Worker Node 1
qm create 202 --name k8s-worker-01 --memory 3072 --cores 3 --net0 virtio,bridge=vmbr0

# Worker Node 2
qm create 203 --name k8s-worker-02 --memory 3072 --cores 3 --net0 virtio,bridge=vmbr0
```

### 2. Install Kubernetes (on all nodes)

```bash
# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Sysctl settings
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd
apt update
apt install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
systemctl restart containerd

# Install kubeadm, kubelet, kubectl
apt install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | \
  tee /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
```

### 3. Initialize Control Plane

```bash
# On control plane node
kubeadm init --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=<CONTROL_PLANE_IP>

# Setup kubectl for root user
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

### 4. Install CNI Plugin (Calico)

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

### 5. Join Worker Nodes

```bash
# Get join command from control plane
kubeadm token create --print-join-command

# Run on each worker node
kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

### 6. Install MetalLB (Load Balancer)

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Configure IP address pool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF
```

### 7. Install Ingress NGINX

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
```

### 8. Deploy OpenFaaS

```bash
# Install arkade (faas-cli installer)
curl -sLS https://get.arkade.dev | sh

# Install OpenFaaS
arkade install openfaas

# Get credentials
PASSWORD=$(kubectl -n openfaas get secret basic-auth -o jsonpath='{.data.basic-auth-password}' | base64 --decode)
echo "OpenFaaS Gateway: http://<GATEWAY_IP>:8080"
echo "Username: admin"
echo "Password: $PASSWORD"
```

## Serverless Functions Integration

### Create Sample Function

```bash
# Install faas-cli
curl -sSL https://cli.openfaas.com | sh

# Login to OpenFaaS
faas-cli login --gateway http://<GATEWAY_IP>:8080 --password $PASSWORD

# Create function
faas-cli new --lang python3 db-backup

# Edit db-backup/handler.py
cat > db-backup/handler.py <<EOF
def handle(req):
    """Backup database function"""
    import os
    from pymongo import MongoClient

    client = MongoClient(os.getenv('MONGO_URI'))
    # Backup logic here

    return "Backup completed"
EOF

# Build and deploy
faas-cli build -f db-backup.yml
faas-cli push -f db-backup.yml
faas-cli deploy -f db-backup.yml
```

### Function Use Cases

1. **Database Backups** - Scheduled backups triggered by cron
2. **ETL Pipelines** - Data transformation jobs
3. **API Endpoints** - Lightweight microservices
4. **Event Processing** - Message queue consumers
5. **AI/ML Inference** - Call AI models for predictions

## CI/CD Integration

### Deployment Pipeline

```yaml
# .gitlab-ci.yml
deploy:
  stage: deploy
  script:
    - kubectl set image deployment/myapp myapp=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - kubectl rollout status deployment/myapp
  only:
    - main
```

### ArgoCD (GitOps Alternative)

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Monitoring & Observability

### Prometheus + Grafana

```bash
# Install kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack
```

### Logging (EFK Stack)

```bash
# Elasticsearch, Fluentd, Kibana
kubectl apply -f https://raw.githubusercontent.com/fluent/fluentd-kubernetes-daemonset/master/fluentd-daemonset-elasticsearch.yaml
```

## Storage Configuration

### Local Path Provisioner

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

### Persistent Volume Example

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path
```

## Network Architecture

```
Internet → Ingress NGINX → Services → Pods
                ↓
         MetalLB (LoadBalancer)
                ↓
         Worker Nodes
```

## Security Best Practices

- **RBAC** - Role-based access control for users/services
- **Network Policies** - Restrict pod-to-pod communication
- **Pod Security Standards** - Enforce security contexts
- **Secrets Management** - Use Sealed Secrets or External Secrets Operator
- **Image Scanning** - Trivy or Clair integration

## High Availability Considerations

For production environments:
- **3 Control Plane Nodes** - etcd quorum
- **3+ Worker Nodes** - Workload distribution
- **External etcd** - Separate etcd cluster
- **Multi-zone deployment** - Spread across availability zones

## Backup Strategy

```bash
# Backup etcd (on control plane)
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Backup cluster configuration
kubectl get all --all-namespaces -o yaml > /backup/cluster-backup.yaml
```

## Common Operations

### Scale Deployment
```bash
kubectl scale deployment myapp --replicas=5
```

### Rolling Update
```bash
kubectl set image deployment/myapp myapp=myapp:v2
```

### Rollback
```bash
kubectl rollout undo deployment/myapp
```

### Drain Node (maintenance)
```bash
kubectl drain k8s-worker-01 --ignore-daemonsets
```

## Troubleshooting

```bash
# Check node status
kubectl get nodes

# Check pod logs
kubectl logs <pod-name>

# Describe pod for events
kubectl describe pod <pod-name>

# Check cluster health
kubectl cluster-info
kubectl get componentstatuses
```

## Cost Optimization

- Use **resource requests/limits** to prevent overcommitment
- Implement **Horizontal Pod Autoscaling** for dynamic scaling
- Use **Cluster Autoscaler** for node scaling
- Enable **Pod Disruption Budgets** for controlled evictions

## Next Steps

1. Deploy VMs and install Kubernetes
2. Configure networking (CNI, MetalLB, Ingress)
3. Install OpenFaaS for serverless functions
4. Set up monitoring and logging
5. Integrate with CI/CD pipeline
6. Deploy sample applications

---

**Related Projects:**
- [CI/CD Platform](./01-cicd-platform.md) - Build and push images
- [DB Cluster](./03-db-cluster.md) - Database backends for applications
- [AI/ML Workbench](./04-aiml-workbench.md) - Inference API integration
