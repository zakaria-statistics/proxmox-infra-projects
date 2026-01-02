# Proxmox Infrastructure Projects

## Overview

This document outlines a comprehensive Proxmox-based infrastructure architecture designed for DevOps, AI/ML development, and security testing. The architecture is optimized for a system with 16-32GB RAM and leverages both LXC containers and VMs strategically.

## Learning Philosophy: Native First, Managed Later

**Master native Kubernetes primitives before adopting managed abstractions.**

This approach ensures you understand:
- What managed tools are abstracting away
- How to troubleshoot when abstractions fail
- How to make informed architectural decisions
- The underlying mechanics of Kubernetes

**Progression:**
1. Native K8s resources (Deployments, Services, HPA, StatefulSets)
2. Manual operations (scaling, updates, monitoring)
3. **Then** managed abstractions (Helm, Operators, OpenFaaS)

---

## Final Architecture

### 1. CI/CD Platform (Dev/Build tier)
- **Type:** LXC (lightweight, no kernel isolation needed)
- GitLab (or Gitea + Drone/Woodpecker for lighter option)
- Container registry
- Builds, tests, pushes images
- **RAM:** 3-4GB | **vCPU:** 4

### 2. K8s Platform (Runtime tier)

#### Phase 2a: Native Kubernetes (Core Learning)
- **Type:** 3 VMs (kubeadm needs full kernel control)
- 1 control plane + 2 workers
- **Master these native concepts first:**
  - Deployments & ReplicaSets (pod management)
  - Services (ClusterIP, NodePort, LoadBalancer)
  - Ingress (HTTP routing) ✅
  - ConfigMaps & Secrets (configuration)
  - PersistentVolumes & PVCs (storage) ✅
  - **HPA (Horizontal Pod Autoscaler)** - autoscaling
  - **Metrics Server** - resource metrics
  - Resource requests/limits (scheduling)
  - StatefulSets (stateful applications)
  - DaemonSets (node-level services)
  - Jobs & CronJobs (batch workloads)

#### Phase 2b: Managed Abstractions (Optional, After Mastery)
- Helm (package manager)
- Operators (custom controllers)
- OpenFaaS/Knative (serverless - abstracts Deployments, Services, HPA)
- Service Mesh (Istio/Linkerd - abstracts networking)

**RAM:** 6-8GB total | **vCPU:** 8 total

### 3. DB Cluster (Stateful tier) !z! practice dbs outside kube !z!
- **Type:** LXC (MongoDB/Postgres run fine in containers)
- MongoDB replica set (3 instances) OR Postgres + Patroni
- etcd for election/consensus practice
- **Native K8s concepts practiced:**
  - StatefulSets (ordered deployment, stable network IDs)
  - Headless Services (DNS for each pod)
  - PersistentVolumeClaims (per-pod storage)
  - Init Containers (database initialization)
- **Advanced integration (Phase 2b):**
  - K8s CronJobs for backups (native)
  - OpenFaaS functions for ETL (managed, optional)
- **RAM:** 3-4GB | **vCPU:** 4

### 4. AI/ML Workbench
- **Type:** VM (GPU passthrough requires full VM)
- Ollama, ChromaDB, Jupyter, LangChain
- RAG, embeddings, fine-tuning, agents, MCP
- **RAM:** 8-12GB | **vCPU:** 8 | **GPU:** Ada passthrough

### 5. Security Lab (Isolated)
- **Type:** VMs (Kali needs full OS, targets need isolation)
- Isolated VLAN
- Kali + vulnerable targets (DVWA, Metasploitable)
- pfSense/OPNsense for firewall practice
- **RAM:** 4-6GB | **vCPU:** 6

### 6. MCP Servers (Integration Layer)
- **Type:** Development project (runs on host/workstation)
- **Purpose:** Custom MCP (Model Context Protocol) servers for infrastructure automation
- **Components:**
  - **k8s-mcp:** Kubernetes cluster management and operations
  - **docker-mcp:** Docker container operations and compose management
  - **security-mcp:** Security scanning (GitGuardian API, trivy, gitleaks), secret detection across all repos, policy checks, audit analysis
  - **proxmox-mcp:** Proxmox VM/CT operations, resource monitoring
- **Integration:** Each MCP server provides AI-assisted management for its respective platform
- **Learning Path:**
  1. Study MCP specification and existing implementations
  2. Build custom servers for each ecosystem
  3. Integrate with Claude for intelligent infrastructure management
- **No additional RAM:** Development tooling, not a running service

---

## LXC vs VM Summary

| Environment | Type | Why |
|-------------|------|-----|
| CI/CD | LXC | Stateless builds, no special kernel needs |
| K8s nodes | VM | kubeadm needs kernel modules, cgroups control |
| DB Cluster | LXC | Databases run fine, saves RAM |
| AI/ML | VM | GPU passthrough requires VM |
| Security | VM | Full OS isolation, network segmentation |

---

## Serverless Functions Note (Advanced/Optional)

**Only after mastering native K8s concepts (Phase 2a)**

Serverless functions are **not a separate environment** — they're managed abstractions that:
- Abstract away: Deployments, Services, HPA, autoscaling logic
- Live as code in CI/CD (built/pushed there)
- Run on K8s (OpenFaaS/Knative runtime)
- **Alternative native approach:** Use K8s CronJobs + Deployments + HPA manually

**Before using serverless, understand what it replaces:**
```
Native K8s:
  Deployment (your code) + Service + HPA + Metrics Server
    ↓ (abstracts to)
OpenFaaS:
  Function (same code, managed scaling/routing)
```

**Integration flow (Phase 2b):**
```
CI/CD (build) → K8s (run function) → DB Cluster (backup/ETL target)
                       ↓
                   AI/ML (inference)
```

---

## RAM Totals

| Mode | Running | RAM |
|------|---------|-----|
| **DevOps** | CI/CD + K8s + DB | ~14GB |
| **AI** | AI/ML workbench | ~10GB |
| **Security** | Security lab | ~5GB |

**With 32GB:** DevOps + AI concurrently
**With 16GB:** One mode at a time

---

## Implementation Strategy (Native-First Approach)

1. **Phase 1:** Set up CI/CD platform (LXC) for foundational automation
   - GitLab/Gitea + Drone
   - Container registry
   - CI/CD pipelines

2. **Phase 2a: K8s Native Concepts** ⚠️ **MASTER THIS FIRST**
   - Deploy K8s cluster (3 VMs) ✅
   - CNI (Calico), LoadBalancer (MetalLB), Ingress ✅
   - **Practice native resources:**
     - Deployments, ReplicaSets, Services ✅
     - Metrics Server + HPA (autoscaling) ⬅️ **CURRENT**
     - ConfigMaps, Secrets
     - StatefulSets (prepare for Phase 3)
     - Jobs, CronJobs
     - Resource quotas, limits

3. **Phase 2b: K8s Managed Abstractions** (OPTIONAL - After mastery)
   - Helm charts
   - Operators
   - OpenFaaS/Knative (serverless)
   - Service Mesh

4. **Phase 3:** Implement DB cluster (LXC)
   - MongoDB/Postgres with StatefulSets
   - Practice: StatefulSets, Headless Services, Init Containers
   - Native CronJobs for backups

5. **Phase 4:** Configure AI/ML workbench (VM) with GPU passthrough
   - Ollama, ChromaDB, Jupyter, LangChain

6. **Phase 5:** Establish isolated security lab (VMs)
   - Kali + targets with network segmentation

7. **Phase 6:** Build MCP Servers (Parallel to other phases)
   - Study MCP specification and protocol
   - Build k8s-mcp (enhances Phase 2 K8s management)
   - Build docker-mcp (enhances CI/CD operations)
   - Build security-mcp (integrates with Phase 5 security lab)
   - Build proxmox-mcp (manages underlying infrastructure)
   - **Cross-cutting:** Can be developed alongside other phases as each platform is deployed

---

## Technology Stack

### Core (Native Kubernetes)
- **Hypervisor:** Proxmox VE
- **Container Runtime:** LXC / Kubernetes (containerd)
- **CI/CD:** GitLab / Gitea + Drone
- **Orchestration:** Kubernetes (kubeadm)
- **Networking:** Calico (CNI), MetalLB (LoadBalancer), Nginx Ingress
- **Storage:** local-path-provisioner, StatefulSets with PVCs
- **Autoscaling:** Metrics Server + HPA
- **Databases:** MongoDB / PostgreSQL (StatefulSets)
- **AI/ML:** Ollama, ChromaDB, Jupyter, LangChain
- **Security:** Kali Linux, DVWA, Metasploitable, pfSense
- **Integration:** MCP Servers (k8s-mcp, docker-mcp, security-mcp, proxmox-mcp)

### Advanced (Managed Abstractions - Phase 2b, Optional)
- **Package Management:** Helm
- **Custom Controllers:** Operators
- **Serverless:** OpenFaaS / Knative (after mastering native HPA/Deployments)
- **Service Mesh:** Istio / Linkerd (after mastering native Services/Ingress)

---

## Cloud Infrastructure Projects

**See: `cloud-infra/` directory**

After mastering native Kubernetes on Proxmox, extend your knowledge to cloud platforms (Azure AKS, AWS EKS, GCP GKE).

**Cloud projects cover:**
- **Provisioning:** Terraform (IaC for creating clusters)
- **Configuration:** Ansible (cluster setup, add-ons, monitoring)
- **DevOps:** CI/CD integration, GitOps concepts
- **Architectures:** Native cloud, Hybrid (Proxmox + Cloud), Multi-cloud patterns

**Key files:**
- `cloud-infra/README.md` - Overview and quick start
- `cloud-infra/docs/architectures.md` - Native/Hybrid/Multi-cloud patterns
- `cloud-infra/docs/provisioning.md` - Terraform for Azure/AWS/GCP
- `cloud-infra/docs/configuration.md` - Ansible for cluster configuration
- `cloud-infra/docs/gitops.md` - GitOps concepts (learn native kubectl first)

**Prerequisites:**
- ✅ Complete Phase 2a (Native Kubernetes on Proxmox)
- ✅ Understand Deployments, Services, Ingress, HPA
- ✅ Comfortable with kubectl operations

**Why cloud after on-prem:**
```
Proxmox (On-Prem)          Cloud (AKS/EKS/GKE)
─────────────────          ───────────────────
Learn fundamentals   →     Apply at scale
Full control         →     Managed services
Manual operations    →     Automated workflows
Low cost             →     Higher cost, higher velocity
```

---

*Last Updated: 2026-01-02*
