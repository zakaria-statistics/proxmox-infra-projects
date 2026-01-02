# Cloud Infrastructure Projects

**Prerequisites:** Master native Kubernetes on Proxmox first (see `../proxmox-infra-projects.md`)

## Directory Structure

```
cloud-infra/
├── azure/          # Azure (AKS) - Primary cloud focus
├── aws/            # AWS (EKS) - Secondary cloud focus
├── gcp/            # GCP (GKE) - Tertiary cloud focus
├── shared/
│   ├── terraform-modules/    # Reusable IaC modules
│   ├── ansible-playbooks/    # Configuration management
│   └── k8s-manifests/        # Portable Kubernetes YAML
├── docs/
│   ├── provisioning.md       # Terraform patterns
│   ├── configuration.md      # Ansible patterns
│   ├── architectures.md      # Native/Hybrid/Multi-cloud
│   └── gitops.md            # GitOps concepts (learn native first)
└── README.md                 # This file
```

## Learning Philosophy

### On-Prem First, Cloud Second

Your Proxmox K8s cluster teaches **what** Kubernetes is.
Cloud platforms teach **how** to operate it at scale.

**Translation:**
```
On-Prem (Proxmox)              Cloud (Managed K8s)
─────────────────              ───────────────────
kubeadm setup          →       Managed control plane
Manual operations      →       Automation at scale
Full control           →       Managed abstractions
Understand primitives  →       Leverage services
```

### Tooling Strategy

**1. Provisioning = Terraform (Infrastructure as Code)**
- Provision cloud resources (VPCs, subnets, K8s clusters)
- Declarative, idempotent, version-controlled
- Works across Azure/AWS/GCP
- See: `docs/provisioning.md`

**2. Configuration = Ansible (Config Management)**
- Configure provisioned resources (cluster settings, add-ons)
- Install monitoring, ingress controllers, storage drivers
- OS-level configuration for worker nodes
- See: `docs/configuration.md`

**3. Deployment = Native kubectl → GitOps (later)**
- **Start:** Manual kubectl apply (understand what you're doing)
- **Later:** ArgoCD/Flux (automation, but know the primitives)
- See: `docs/gitops.md`

**Workflow:**
```
Terraform (provision cluster)
    ↓
Ansible (configure cluster: metrics-server, ingress, monitoring)
    ↓
kubectl (deploy applications - native YAML)
    ↓
GitOps (automate deployments - after mastering native)
```

---

## Cloud Platform Priorities

### 1. Azure (Primary) - `azure/`
- **Why first:** Enterprise-dominant, strong Kubernetes support
- **Focus:** AKS (Azure Kubernetes Service)
- **Key features:** Azure CNI, Application Gateway Ingress, Azure AD integration
- **Cert path:** AZ-900 → AZ-104 → AZ-204 → AZ-305

### 2. AWS (Secondary) - `aws/`
- **Why second:** Market leader, most mature cloud
- **Focus:** EKS (Elastic Kubernetes Service)
- **Key features:** VPC CNI, ALB Ingress Controller, IRSA
- **Cert path:** Cloud Practitioner → Solutions Architect → DevOps Engineer

### 3. GCP (Tertiary) - `gcp/`
- **Why third:** Kubernetes birthplace, innovative features
- **Focus:** GKE (Google Kubernetes Engine), GKE Autopilot
- **Key features:** VPC-native clusters, Workload Identity, Autopilot mode
- **Cert path:** Associate Cloud Engineer → Professional Cloud Architect

---

## Architecture Patterns

See `docs/architectures.md` for detailed discussion:

### Native Cloud
- Single cloud provider (e.g., only Azure)
- Deep integration with cloud services
- Simplest to manage, highest lock-in

### Hybrid Cloud
- On-prem (Proxmox) + Cloud (AKS/EKS/GKE)
- VPN/ExpressRoute/Direct Connect connectivity
- Data sovereignty, gradual migration

### Multi-Cloud
- Multiple cloud providers (Azure + AWS + GCP)
- Portable Kubernetes abstractions
- Highest complexity, lowest lock-in

---

## Quick Start

### Prerequisites
```bash
# Install tools
brew install terraform ansible kubectl helm  # macOS
# OR
apt install terraform ansible kubectl        # Linux

# Install cloud CLIs
brew install azure-cli awscli google-cloud-sdk
```

### 1. Azure (Start Here)
```bash
cd azure/
# Follow azure/README.md for:
# - Terraform: Provision AKS cluster
# - Ansible: Configure cluster (metrics, ingress, monitoring)
# - kubectl: Deploy test application
```

### 2. AWS (After Azure)
```bash
cd aws/
# Follow aws/README.md
```

### 3. GCP (After AWS)
```bash
cd gcp/
# Follow gcp/README.md
```

---

## Key Concepts

### What is CaaS (Containers as a Service)?

**Your Proxmox setup** (self-managed):
- You provision VMs (Proxmox)
- You install Kubernetes (kubeadm)
- You configure networking (Calico)
- You manage upgrades, scaling, monitoring

**Cloud CaaS** (managed):
- Cloud provisions VMs (automatic)
- Cloud installs K8s (managed control plane)
- Cloud configures networking (VPC integration)
- Cloud manages upgrades, provides autoscaling

**What you still manage in both:**
- Application deployments (YAML manifests)
- Services, Ingress, ConfigMaps
- Horizontal Pod Autoscaler (HPA)
- Your application code and containers

**What CaaS abstracts:**
- Control plane maintenance (etcd, api-server, scheduler)
- Node provisioning and lifecycle
- Cloud service integration (load balancers, storage)
- Monitoring and logging infrastructure

### Portable vs Cloud-Specific

**Portable (works everywhere):**
```yaml
# This Deployment works identically on Proxmox, AKS, EKS, GKE
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:v1
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
```

**Cloud-specific (vendor lock-in):**
```yaml
# Azure-specific: Application Gateway Ingress
annotations:
  kubernetes.io/ingress.class: "azure/application-gateway"

# AWS-specific: ALB Ingress
annotations:
  kubernetes.io/ingress.class: "alb"
  alb.ingress.kubernetes.io/scheme: "internet-facing"

# GCP-specific: Workload Identity
annotations:
  iam.gke.io/gcp-service-account: "myapp@project.iam.gserviceaccount.com"
```

**Strategy:**
- Use portable patterns by default
- Use cloud-specific features when they provide clear value
- Document cloud-specific dependencies

---

## Cost Management

### Development Clusters (Learning)

**Minimize costs:**
```bash
# Azure: Free tier control plane
az aks create --tier free --node-vm-size Standard_B2s --node-count 2

# AWS: eksctl with small instances
eksctl create cluster --node-type t3.small --nodes 2

# GCP: Autopilot (pay per pod, not per node)
gcloud container clusters create-auto my-cluster
```

**Auto-shutdown:**
- Scale node pools to 0 at night/weekends
- Delete dev clusters when not in use
- Use Azure Automation / AWS Lambda / GCP Cloud Scheduler

**Typical dev cluster costs:**
- Azure AKS: ~$75-100/month (free control plane + 2 B2s nodes)
- AWS EKS: ~$150-200/month ($73 control plane + 2 t3.small nodes)
- GCP GKE: ~$100-150/month (Autopilot, pay-per-pod)

### Production Clusters

**Optimize:**
- Reserved instances (1-3 year: 30-50% savings)
- Spot/Preemptible nodes for batch workloads (60-90% savings)
- Cluster Autoscaler (scale based on demand)
- Right-size node types (don't over-provision)

---

## Next Steps

1. **Read:** `docs/architectures.md` - Understand native/hybrid/multi-cloud patterns
2. **Provision:** Start with `azure/` - Terraform AKS cluster
3. **Configure:** Use Ansible to install cluster add-ons
4. **Deploy:** Use native kubectl to deploy applications
5. **Expand:** Repeat for AWS, then GCP
6. **Automate:** Explore GitOps after mastering native operations

---

*Last Updated: 2026-01-02*