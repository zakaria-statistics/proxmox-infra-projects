# Cloud Architecture Patterns

## Native, Hybrid, and Multi-Cloud Explained

### 1. Native Cloud (Single Provider)

**Definition:** All infrastructure on one cloud provider with deep integration.

**Architecture:**
```
┌─────────────────────────────────────────────────┐
│           Azure Cloud (example)                  │
│                                                  │
│  ┌────────────┐     ┌─────────────┐            │
│  │    AKS     │────▶│  Azure SQL  │            │
│  │  Cluster   │     │  Database   │            │
│  └────────────┘     └─────────────┘            │
│        │                                        │
│        │            ┌─────────────┐            │
│        └───────────▶│   Cosmos    │            │
│                     │     DB      │            │
│                     └─────────────┘            │
│                                                 │
│  All networking via Azure VNet                 │
│  All IAM via Azure AD                          │
│  All monitoring via Azure Monitor              │
└─────────────────────────────────────────────────┘
```

**Characteristics:**
- **Deep Integration:** Native services (Azure AD, Azure SQL, Cosmos DB)
- **Simplest Operations:** Single CLI, single IAM system, single bill
- **Best Performance:** Low latency between services (same datacenter)
- **Highest Lock-in:** Hard to migrate to another provider

**When to use:**
- Small to medium applications
- Team has expertise in one cloud
- Cost optimization via reserved instances
- Corporate cloud strategy (e.g., "Azure-first")

**Example: E-commerce on Azure**
```
Components:
- AKS cluster (application runtime)
- Azure SQL Database (transactional data)
- Cosmos DB (product catalog, shopping cart)
- Azure Cache for Redis (session storage)
- Azure Blob Storage (images, static assets)
- Application Gateway (ingress)
- Azure AD (authentication)
```

**Terraform Example:**
```hcl
# All resources in one cloud
resource "azurerm_kubernetes_cluster" "aks" {
  name     = "aks-prod"
  location = "eastus"
  # ...
}

resource "azurerm_sql_server" "sql" {
  name     = "sqlserver-prod"
  location = "eastus"
  # ...
}

resource "azurerm_cosmosdb_account" "cosmos" {
  name     = "cosmos-prod"
  location = "eastus"
  # ...
}
```

---

### 2. Hybrid Cloud (On-Prem + Cloud)

**Definition:** Combine on-premises infrastructure (Proxmox) with cloud resources.

**Architecture:**
```
┌──────────────────────────┐         ┌──────────────────────────┐
│   On-Premises (Proxmox)  │         │    Azure Cloud (AKS)     │
│                          │         │                          │
│  ┌────────────┐         │         │  ┌────────────┐         │
│  │    K8s     │         │         │  │    AKS     │         │
│  │  Cluster   │         │         │  │  Cluster   │         │
│  └────────────┘         │         │  └────────────┘         │
│        │                │         │        │                │
│        │                │         │        │                │
│  ┌────────────┐         │         │  ┌────────────┐         │
│  │  MongoDB   │         │         │  │   Cosmos   │         │
│  │  Replica   │         │         │  │     DB     │         │
│  └────────────┘         │         │  └────────────┘         │
│                         │         │                          │
└─────────┬───────────────┘         └────────┬─────────────────┘
          │                                  │
          │      VPN/ExpressRoute/VPC        │
          │         Peering Connection       │
          └──────────────────────────────────┘
                   Encrypted Tunnel
```

**Connectivity Options:**

**Option 1: Site-to-Site VPN (Cheaper)**
```
On-Prem Router ←→ VPN Gateway ←→ Azure VPN Gateway
- Speed: Up to 1 Gbps
- Cost: ~$50-100/month
- Latency: 20-50ms (over internet)
- Use case: Development, low-bandwidth workloads
```

**Option 2: ExpressRoute/Direct Connect (Faster)**
```
On-Prem Router ←→ ISP Fiber ←→ Azure ExpressRoute
- Speed: 50 Mbps to 100 Gbps
- Cost: ~$500-5000/month
- Latency: 5-10ms (dedicated circuit)
- Use case: Production, high-bandwidth, low-latency
```

**Option 3: Kubernetes Federation (Application-level)**
```
ArgoCD/Kubefed on Cloud
    ↓ (manages both)
Proxmox K8s Cluster + AKS Cluster
    ↓ (shared workloads)
Applications span both environments
```

**Use Cases:**

**A. Data Sovereignty**
```
Sensitive data → On-prem Proxmox K8s cluster (compliance)
Public APIs    → Cloud AKS cluster (scalability)
```

**B. Burst to Cloud**
```
Normal load  → On-prem (cheaper)
Peak traffic → Cloud autoscaling (elasticity)
```

**C. Gradual Migration**
```
Legacy apps     → On-prem (keep running)
New services    → Cloud (modern architecture)
Incremental migration over time
```

**D. Disaster Recovery**
```
Primary: On-prem Proxmox K8s
Backup:  Cloud AKS cluster (sync via Velero)
Failover in case of on-prem failure
```

**Terraform Example:**
```hcl
# On-prem resources (via Proxmox provider)
resource "proxmox_vm_qemu" "k8s_node" {
  name = "k8s-worker-1"
  # ...
}

# Cloud resources
resource "azurerm_kubernetes_cluster" "aks" {
  name = "aks-prod"
  # ...
}

# VPN connection
resource "azurerm_virtual_network_gateway" "vpn" {
  name = "azure-vpn-gateway"
  # ...
}

resource "azurerm_local_network_gateway" "onprem" {
  name            = "onprem-gateway"
  gateway_address = "203.0.113.10"  # Your public IP
  # ...
}
```

**Challenges:**
- Network latency between environments
- Complex networking (VPN setup, routing, DNS)
- Security (firewall rules, encryption)
- Data consistency across locations
- Dual operations (manage both on-prem and cloud)

---

### 3. Multi-Cloud (Multiple Cloud Providers)

**Definition:** Distribute workloads across Azure, AWS, and GCP.

**Architecture:**
```
                    ┌─────────────────┐
                    │   ArgoCD/Flux   │
                    │ (GitOps Control)│
                    └────────┬────────┘
                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
           ▼                 ▼                 ▼
    ┌────────────┐    ┌────────────┐    ┌────────────┐
    │   Azure    │    │    AWS     │    │    GCP     │
    │    AKS     │    │    EKS     │    │    GKE     │
    └────────────┘    └────────────┘    └────────────┘
           │                 │                 │
           ▼                 ▼                 ▼
    ┌────────────┐    ┌────────────┐    ┌────────────┐
    │  Region:   │    │  Region:   │    │  Region:   │
    │   East US  │    │ us-east-1  │    │us-central1 │
    └────────────┘    └────────────┘    └────────────┘

    Same application, different clouds
```

**Strategies:**

**A. Active-Active (Geographic Distribution)**
```
Users in Europe → Azure (West Europe)
Users in USA    → AWS (us-east-1)
Users in Asia   → GCP (asia-southeast1)

Benefits:
- Low latency for global users
- Regional compliance (GDPR, data residency)
- No single point of failure
```

**B. Active-Passive (Disaster Recovery)**
```
Primary:   Azure AKS (100% traffic)
Secondary: AWS EKS (standby, 0% traffic)
Failover:  DNS switch to AWS on Azure outage

Benefits:
- Cloud provider failure resilience
- Reduced blast radius
```

**C. Workload Segregation**
```
Compute-intensive → GCP (TPU/GPU pricing)
Data analytics    → AWS (mature data services)
Enterprise apps   → Azure (Microsoft integration)

Benefits:
- Use best-of-breed services
- Cost optimization per workload type
```

**D. Vendor Negotiation Leverage**
```
Spread workloads across providers
Negotiate better pricing (you can switch)

Benefits:
- Lower costs through competition
- Reduced lock-in
```

**Portable Kubernetes Patterns:**

```yaml
# WORKS EVERYWHERE: Standard Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: ghcr.io/myorg/myapp:v1  # Public registry
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: url
---
# WORKS EVERYWHERE: Service
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  type: LoadBalancer  # AKS/EKS/GKE all create cloud LB
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: myapp
```

**Cloud-Specific Adaptations:**

```yaml
# values-azure.yaml (AKS-specific)
ingress:
  enabled: true
  className: "azure/application-gateway"
  annotations:
    appgw.ingress.kubernetes.io/ssl-redirect: "true"

storage:
  storageClass: "managed-premium"  # Azure Premium SSD

---
# values-aws.yaml (EKS-specific)
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: "internet-facing"
    alb.ingress.kubernetes.io/target-type: "ip"

storage:
  storageClass: "gp3"  # AWS EBS gp3

---
# values-gcp.yaml (GKE-specific)
ingress:
  enabled: true
  className: "gce"
  annotations:
    kubernetes.io/ingress.class: "gce"

storage:
  storageClass: "pd-ssd"  # GCP Persistent Disk SSD
```

**Deployment with Helm:**
```bash
# Single Helm chart, environment-specific values
helm install myapp ./chart --values values-azure.yaml  # Deploy to AKS
helm install myapp ./chart --values values-aws.yaml    # Deploy to EKS
helm install myapp ./chart --values values-gcp.yaml    # Deploy to GKE
```

**Multi-Cloud Networking:**

**Option 1: Public Internet (Simplest)**
```
AKS Cluster ←→ Public LoadBalancer ←→ Internet ←→ EKS Cluster
- Pros: Simple, no VPN setup
- Cons: Higher latency, less secure
- Use: Independent applications, no inter-cluster communication
```

**Option 2: Cloud Interconnects (Complex)**
```
AKS (Azure) ←→ Azure ExpressRoute ←→ Megaport/Equinix ←→ AWS Direct Connect ←→ EKS (AWS)
- Pros: Low latency, private connectivity
- Cons: Expensive ($500-5000/month), complex setup
- Use: Latency-sensitive, high-bandwidth inter-cloud communication
```

**Option 3: Service Mesh (Application-level)**
```
Istio Multi-Cluster
├── AKS cluster (mesh member)
├── EKS cluster (mesh member)
└── GKE cluster (mesh member)

Features:
- Unified service discovery
- Cross-cluster traffic routing
- Mutual TLS between clouds
```

**Terraform for Multi-Cloud:**
```hcl
# terraform/main.tf

# Azure AKS
module "aks" {
  source = "./modules/azure-aks"
  cluster_name = "aks-prod"
  region = "eastus"
}

# AWS EKS
module "eks" {
  source = "./modules/aws-eks"
  cluster_name = "eks-prod"
  region = "us-east-1"
}

# GCP GKE
module "gke" {
  source = "./modules/gcp-gke"
  cluster_name = "gke-prod"
  region = "us-central1"
}

# Outputs for kubeconfig files
output "kubeconfigs" {
  value = {
    aks = module.aks.kubeconfig
    eks = module.eks.kubeconfig
    gke = module.gke.kubeconfig
  }
}
```

**Challenges:**
- **Complexity:** 3x operational overhead (3 clouds to manage)
- **Networking:** Cross-cloud connectivity is expensive/slow
- **Data Consistency:** Distributed databases across clouds
- **Monitoring:** Unified observability across providers
- **Cost:** Higher management overhead, cloud egress fees
- **Expertise:** Team needs knowledge of all 3 platforms

**When Multi-Cloud Makes Sense:**
- Large enterprises with regional compliance needs
- SaaS products serving global customers
- Avoiding catastrophic cloud provider failure
- Regulatory requirements (financial services, healthcare)

**When Multi-Cloud Doesn't Make Sense:**
- Small teams (< 10 engineers)
- Limited budget (cloud egress costs 💸)
- Single-region applications
- Startups/early-stage companies

---

## Decision Matrix

| Pattern | Complexity | Cost | Lock-in | Resilience | When to Use |
|---------|-----------|------|---------|------------|-------------|
| **Native Cloud** | Low | Low | High | Medium | Small apps, single region, team expertise |
| **Hybrid** | Medium | Medium | Medium | High | Data sovereignty, gradual migration, DR |
| **Multi-Cloud** | High | High | Low | Very High | Global apps, regulatory, avoid vendor lock-in |

---

## Recommended Progression

### Phase 1: Native Cloud (Start Here)
1. Master Kubernetes on Proxmox (native concepts)
2. Deploy to Azure AKS (single cloud, deep integration)
3. Learn Terraform + Ansible + kubectl workflow
4. **Goal:** Understand one cloud deeply

### Phase 2: Hybrid Cloud
1. Connect Proxmox K8s to Azure via VPN
2. Practice cross-environment deployments
3. Implement disaster recovery (Velero backups to cloud)
4. **Goal:** Understand networking, data replication

### Phase 3: Multi-Cloud (Advanced)
1. Add AWS EKS cluster
2. Add GCP GKE cluster
3. Implement GitOps for all clusters (ArgoCD)
4. Unified monitoring (Prometheus federation)
5. **Goal:** Portable architectures, cloud-agnostic patterns

---

## Real-World Examples

### Hybrid: Financial Services
```
Proxmox (On-Prem):
- Customer PII (compliance: GDPR, PCI-DSS)
- Core banking system (legacy, can't migrate)

Azure Cloud:
- Mobile banking API (scalable, public-facing)
- Analytics and reporting (Azure Synapse)

Connection: ExpressRoute (low latency, secure)
```

### Multi-Cloud: Global SaaS
```
Azure (Europe):
- EU customers (GDPR compliance)
- Data residency in EU

AWS (USA):
- US customers
- Mature ML services (SageMaker)

GCP (Asia):
- APAC customers
- Low latency for Asian markets

Global: ArgoCD manages all clusters, same application
```

### Native: E-commerce Startup
```
Azure only:
- AKS (application runtime)
- Cosmos DB (product catalog)
- Azure Functions (event processing)
- Application Gateway (ingress)

Why native:
- Small team (5 engineers)
- Focus on product, not infrastructure
- Azure credits via startup program
```

---

## Networking Deep Dive

### DNS and Service Discovery

**Native Cloud:**
```
Azure Private DNS Zone
- aks-cluster.internal → 10.0.0.0/16
- All services resolve within Azure VNet
- Simple: kubectl get svc shows internal IPs
```

**Hybrid Cloud:**
```
On-Prem DNS:
- mongodb.local → 192.168.1.100 (Proxmox)

Azure Private DNS:
- api.azure.internal → 10.0.1.50 (AKS)

VPN Conditional Forwarding:
- *.local → On-prem DNS
- *.azure.internal → Azure DNS
- Services across environments can resolve each other
```

**Multi-Cloud:**
```
External DNS (externalDNS controller on each cluster):
- api.example.com → Route53/Azure DNS/Cloud DNS
- Automatically updates DNS on service creation

OR Service Mesh (Istio):
- Virtual DNS across clusters
- my-service.default.svc.cluster.local resolves across AKS/EKS/GKE
```

### Load Balancing

**Native:**
```yaml
# Service type LoadBalancer creates cloud LB automatically
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  type: LoadBalancer  # Azure LB / AWS NLB / GCP LB
  ports:
  - port: 80
```

**Hybrid:**
```
Option 1: Expose via NodePort + On-prem LB
- AKS Service type: NodePort
- F5 BigIP / HAProxy on-prem routes to AKS nodes

Option 2: Azure Application Gateway (cloud-based)
- Public IP in Azure
- VPN routes traffic to on-prem if needed
```

**Multi-Cloud:**
```
Global Load Balancer:
- Azure Traffic Manager / AWS Route53 / GCP Cloud Load Balancing
- Geographic routing:
  - EU users → AKS
  - US users → EKS
  - Asia users → GKE
```

---

## Security Considerations

### Native Cloud
- Single IAM system (Azure AD / AWS IAM / Google IAM)
- Network policies within VPC
- Managed encryption (Azure Key Vault / AWS KMS / GCP KMS)

### Hybrid Cloud
- VPN encryption (IPSec tunnels)
- Federated identity (Azure AD Connect, AWS SSO)
- Data encryption in transit and at rest
- Firewall rules on both sides

### Multi-Cloud
- Separate IAM per cloud (complexity!)
- Service mesh for mutual TLS (Istio)
- Secret management (HashiCorp Vault spanning clouds)
- Compliance per region (GDPR, SOC2, HIPAA)

---

## Cost Comparison

**Native Cloud (Azure AKS example):**
```
Control Plane: $0-73/month (free tier available)
Worker Nodes: 2x D2s_v3 = $140/month
Load Balancer: $20/month
Storage: 100GB = $10/month
Total: ~$170-240/month
```

**Hybrid Cloud (Proxmox + Azure):**
```
Proxmox (on-prem): One-time hardware cost, $0 software
Azure AKS: $170/month
VPN Gateway: $50/month
ExpressRoute (optional): $500-5000/month
Total: $220/month (VPN) or $670-5170/month (ExpressRoute)
```

**Multi-Cloud (AKS + EKS + GKE):**
```
Azure AKS: $240/month
AWS EKS: $280/month ($73 control plane + nodes)
GCP GKE: $200/month
Cloud Interconnects: $500-1500/month (if needed)
Total: $720-2220/month
```

**Egress Costs (Critical!):**
```
Data transfer within cloud: Free (usually)
Data transfer out to internet:
- Azure: $0.08-0.12/GB
- AWS: $0.09/GB
- GCP: $0.08-0.12/GB

Example: 1TB/month egress = $80-120/month per cloud
Multi-cloud with cross-cloud traffic: $$$ very expensive
```

---

## Summary

**Native Cloud:** Simple, integrated, locked-in
**Hybrid Cloud:** Flexible, complex networking, gradual migration
**Multi-Cloud:** Resilient, expensive, high expertise needed

**Recommendation:**
1. Start with native cloud (Azure AKS)
2. Experiment with hybrid (Proxmox + Azure)
3. Only pursue multi-cloud if you have clear business requirements

---

*Last Updated: 2026-01-02*