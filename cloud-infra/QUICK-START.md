# Cloud Infrastructure Quick Start

## What Was Created

```
cloud-infra/
├── README.md                    # Start here - Overview and philosophy
├── QUICK-START.md              # This file
├── docs/
│   ├── architectures.md        # Native/Hybrid/Multi-cloud patterns
│   ├── provisioning.md         # Terraform for IaC
│   ├── configuration.md        # Ansible for cluster config
│   └── gitops.md              # GitOps concepts (native first!)
├── azure/                      # Azure (AKS) - Primary focus
├── aws/                        # AWS (EKS) - Secondary
├── gcp/                        # GCP (GKE) - Tertiary
└── shared/
    ├── terraform-modules/      # Reusable Terraform code
    ├── ansible-playbooks/      # Reusable Ansible playbooks
    └── k8s-manifests/         # Portable Kubernetes YAML
```

## Learning Path

### Prerequisites (Complete First!)
- ✅ Proxmox K8s cluster running (native concepts)
- ✅ Understand: Deployments, Services, Ingress, ConfigMaps
- ✅ Comfortable with: kubectl apply, get, describe, logs
- ✅ Practiced: HPA, StatefulSets (recommended)

### Phase 1: Understand Architectures (1-2 hours reading)
**File:** `docs/architectures.md`

Learn about:
- **Native Cloud:** Single cloud provider (Azure, AWS, or GCP)
- **Hybrid Cloud:** On-prem Proxmox + Cloud provider
- **Multi-Cloud:** Multiple clouds (Azure + AWS + GCP)

**Decide:** Which architecture fits your goals?
- Learning? → Start with **Native Cloud** (Azure recommended)
- Migration? → Consider **Hybrid Cloud** (Proxmox + Azure)
- Enterprise? → Explore **Multi-Cloud** (after mastering native)

### Phase 2: Provisioning with Terraform (1 week)
**File:** `docs/provisioning.md`

**What you'll learn:**
- Infrastructure as Code (IaC) concepts
- Terraform basics: init, plan, apply, destroy
- Provision AKS/EKS/GKE clusters
- Network setup (VPCs, subnets, load balancers)
- Remote state management

**Hands-on:**
```bash
cd azure/terraform/
# Follow provisioning.md examples
terraform init
terraform plan
terraform apply
```

**Outcome:** Working AKS/EKS/GKE cluster

### Phase 3: Configuration with Ansible (1 week)
**File:** `docs/configuration.md`

**What you'll learn:**
- Ansible playbooks and inventory
- Install cluster add-ons: Metrics Server, Ingress, Monitoring
- OS-level configuration
- Cloud-specific integrations

**Hands-on:**
```bash
cd shared/ansible-playbooks/
# Follow configuration.md examples
ansible-playbook -i inventory/azure.ini playbooks/bootstrap-cluster.yml
```

**Outcome:** Fully configured cluster with monitoring, ingress, autoscaling

### Phase 4: Native Deployments (2-4 weeks)
**File:** `docs/gitops.md` (Section: "Native kubectl Workflow")

**What you'll practice:**
- Deploy applications with native kubectl
- Update, scale, rollback deployments
- Debug issues with logs, events, describe
- Understand what you're doing (critical!)

**Hands-on:**
```bash
# Deploy test app
kubectl apply -f shared/k8s-manifests/test-app/
kubectl get pods
kubectl logs <pod>
kubectl scale deployment/test-app --replicas=5
```

**Outcome:** Confidence with kubectl, understanding of K8s primitives

### Phase 5: GitOps (After Phase 4)
**File:** `docs/gitops.md`

**What you'll learn:**
- Git as source of truth
- ArgoCD/Flux for automated deployments
- Multi-cluster management
- Drift detection and self-healing

**Hands-on:**
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Follow gitops.md for application setup
```

**Outcome:** Automated deployments from Git, production-ready workflows

---

## Quick Command Reference

### Terraform (Provisioning)
```bash
# Initialize
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy resources (dev only!)
terraform destroy

# Get outputs
terraform output
```

### Ansible (Configuration)
```bash
# Run playbook
ansible-playbook -i inventory/<cloud>.ini playbooks/<playbook>.yml

# Check mode (dry-run)
ansible-playbook playbook.yml --check

# Specific tags
ansible-playbook playbook.yml --tags monitoring

# Vault for secrets
ansible-vault encrypt_string 'secret' --name 'var_name'
```

### kubectl (Deployment)
```bash
# Apply manifests
kubectl apply -f <file>.yaml

# Get resources
kubectl get pods/deployments/services

# Describe resource
kubectl describe pod <name>

# View logs
kubectl logs <pod>

# Scale
kubectl scale deployment/<name> --replicas=3

# Rollout
kubectl rollout status deployment/<name>
kubectl rollout undo deployment/<name>

# Port-forward (debugging)
kubectl port-forward pod/<name> 8080:80
```

### Cloud CLIs
```bash
# Azure
az login
az aks get-credentials --resource-group <rg> --name <cluster>

# AWS
aws configure
aws eks update-kubeconfig --region <region> --name <cluster>

# GCP
gcloud auth login
gcloud container clusters get-credentials <cluster> --region <region>
```

---

## Architecture Decision Guide

**Choose Native Cloud if:**
- Learning cloud platforms for the first time
- Small to medium application
- Team has expertise in one cloud
- Cost optimization via reserved instances

**Choose Hybrid Cloud if:**
- Data sovereignty requirements (keep data on-prem)
- Gradual cloud migration
- Disaster recovery (cloud as backup)
- Want on-prem control + cloud scalability

**Choose Multi-Cloud if:**
- Large enterprise with global presence
- Regulatory compliance across regions
- Avoid vendor lock-in
- SaaS product serving worldwide customers

**For most learners: Start with Native Cloud (Azure AKS recommended)**

---

## Tool Separation

**Clear boundaries:**

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **Terraform** | Provision infrastructure | Create clusters, VPCs, load balancers |
| **Ansible** | Configure infrastructure | Install add-ons, monitoring, security policies |
| **kubectl** | Deploy applications | Create Deployments, Services (native learning) |
| **GitOps** | Automate deployments | Production, teams, multi-env (after native) |

**Workflow:**
```
1. Terraform: Create AKS cluster
2. Ansible: Install Ingress, Metrics, Prometheus
3. kubectl: Deploy your application (learn native)
4. GitOps: Automate step 3 (after mastering kubectl)
```

---

## Costs (Rough Estimates)

### Development/Learning Clusters

**Azure AKS:**
- Control plane: Free (or $73/month standard)
- 2x B2s nodes: ~$60/month
- Load balancer: ~$20/month
- **Total: ~$80-150/month**

**AWS EKS:**
- Control plane: $73/month
- 2x t3.small nodes: ~$60/month
- Load balancer: ~$20/month
- **Total: ~$150-200/month**

**GCP GKE:**
- Standard: ~$100/month (control plane + 2 nodes)
- Autopilot: ~$100/month (pay per pod)
- **Total: ~$100-150/month**

**Cost Savings:**
- Auto-shutdown nights/weekends: Save 60-70%
- Spot/Preemptible nodes: Save 60-90%
- Delete when not in use: Save 100%

### Production Clusters
- Reserved instances: 30-50% savings
- Right-sized nodes: Variable savings
- Cluster autoscaling: Only pay for what you use

---

## Next Steps

1. **Read:** `README.md` (overview and philosophy)
2. **Study:** `docs/architectures.md` (understand patterns)
3. **Choose:** Azure (primary), AWS (secondary), or GCP (tertiary)
4. **Provision:** Follow `docs/provisioning.md` for Terraform
5. **Configure:** Follow `docs/configuration.md` for Ansible
6. **Deploy:** Use native kubectl (see `docs/gitops.md`)
7. **Automate:** GitOps when ready (after mastering native)

**Remember:** This builds on your Proxmox K8s knowledge. Cloud adds managed services, not new Kubernetes concepts.

---

## Support

**Documentation:**
- Terraform: https://www.terraform.io/docs
- Ansible: https://docs.ansible.com/
- Azure AKS: https://learn.microsoft.com/azure/aks/
- AWS EKS: https://docs.aws.amazon.com/eks/
- GCP GKE: https://cloud.google.com/kubernetes-engine/docs

**Certifications:**
- Azure: AZ-900 → AZ-104 → AZ-204
- AWS: Cloud Practitioner → Solutions Architect → DevOps Engineer
- GCP: Associate Cloud Engineer → Professional Cloud Architect
- Kubernetes: CKA → CKAD → CKS

---

*Created: 2026-01-02*
