# Proxmox Infrastructure Projects

A comprehensive home lab infrastructure built on Proxmox for DevOps, AI/ML development, and cybersecurity practice. This repository contains detailed implementation guides for five integrated environments optimized for learning and experimentation.

## Quick Links

- [CI/CD Platform](./01-cicd-platform.md) - Continuous integration and delivery
- [Kubernetes Platform](./02-k8s-platform.md) - Container orchestration and serverless
- [Database Cluster](./03-db-cluster.md) - High-availability data tier
- [AI/ML Workbench](./04-aiml-workbench.md) - Machine learning and LLM development
- [Security Lab](./05-security-lab.md) - Penetration testing environment

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Proxmox VE Hypervisor                       │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │   CI/CD      │  │  K8s Cluster │  │    DB Cluster      │  │
│  │  Platform    │→ │ (3 VMs)      │→ │   (LXC)            │  │
│  │   (LXC)      │  │ - Control    │  │ - MongoDB/PG       │  │
│  │ - GitLab     │  │ - 2 Workers  │  │ - etcd             │  │
│  │ - Registry   │  │ - OpenFaaS   │  │                    │  │
│  └──────────────┘  └──────────────┘  └────────────────────┘  │
│                                                                 │
│  ┌──────────────┐  ┌─────────────────────────────────────┐   │
│  │  AI/ML       │  │      Security Lab (Isolated)        │   │
│  │  Workbench   │  │ ┌─────────┐ ┌─────────┐ ┌────────┐ │   │
│  │   (VM)       │  │ │  Kali   │ │pfSense  │ │Targets │ │   │
│  │ - Ollama     │  │ │ Linux   │ │(Router) │ │(VMs)   │ │   │
│  │ - ChromaDB   │  │ └─────────┘ └─────────┘ └────────┘ │   │
│  │ - Jupyter    │  │         Isolated VLAN               │   │
│  │ - GPU Pass   │  └─────────────────────────────────────┘   │
│  └──────────────┘                                             │
└─────────────────────────────────────────────────────────────────┘
```

## System Requirements

### Minimum Specifications
- **CPU:** 8 cores (16 threads recommended)
- **RAM:** 16GB (one environment at a time)
- **Storage:** 500GB SSD
- **GPU:** Optional (required for AI/ML workbench GPU acceleration)

### Recommended Specifications
- **CPU:** 12+ cores (24 threads)
- **RAM:** 32GB (run multiple environments concurrently)
- **Storage:** 1TB NVMe SSD
- **GPU:** NVIDIA RTX 4000 series (for AI/ML)

## Resource Allocation

| Environment | Type | RAM | vCPU | Storage | Status |
|-------------|------|-----|------|---------|--------|
| CI/CD Platform | LXC | 3-4GB | 4 | 50-100GB | Always-on |
| K8s Cluster | VM | 6-8GB | 8 | 100GB+ | Always-on |
| DB Cluster | LXC | 3-4GB | 4 | 100GB+ | Always-on |
| AI/ML Workbench | VM | 8-12GB | 8 | 200GB+ | On-demand |
| Security Lab | VM | 4-6GB | 6 | 100-150GB | On-demand |

### Operating Modes

**With 32GB RAM:**
- Run DevOps stack (CI/CD + K8s + DB) + AI/ML concurrently
- Or DevOps stack + Security Lab

**With 16GB RAM:**
- Run one mode at a time:
  - DevOps mode: CI/CD + K8s + DB (~14GB)
  - AI mode: AI/ML Workbench (~10GB)
  - Security mode: Security Lab (~5GB)

## Technology Stack

### DevOps & Infrastructure
- **Hypervisor:** Proxmox VE 8.x
- **Containers:** LXC, Docker, containerd
- **Orchestration:** Kubernetes (kubeadm)
- **CI/CD:** GitLab CE / Gitea + Drone
- **Serverless:** OpenFaaS / Knative
- **Networking:** Calico/Flannel CNI, MetalLB
- **Monitoring:** Prometheus, Grafana

### Data & Storage
- **Databases:** MongoDB, PostgreSQL
- **HA Tools:** Patroni, etcd
- **Vector DB:** ChromaDB, Chroma
- **Storage:** Local Path Provisioner, Longhorn

### AI & Machine Learning
- **LLM Runtime:** Ollama
- **Frameworks:** LangChain, PyTorch, TensorFlow
- **Notebooks:** JupyterLab
- **Protocols:** MCP (Model Context Protocol)
- **Models:** Llama 3, Mistral, CodeLlama, Embeddings

### Security & Testing
- **Attack Platform:** Kali Linux
- **Firewall/Router:** pfSense / OPNsense
- **IDS/IPS:** Snort, Suricata
- **Targets:** DVWA, Metasploitable, VulnHub VMs

## Project Guides

### 1. [CI/CD Platform](./01-cicd-platform.md)
Build, test, and deploy applications with automated pipelines.

**Key Features:**
- Git repository hosting
- Automated build pipelines
- Container registry
- Artifact management

**Technologies:** GitLab/Gitea, Docker, GitLab Runner/Drone

**Time to Deploy:** 2-4 hours

---

### 2. [Kubernetes Platform](./02-k8s-platform.md)
Production-grade container orchestration with serverless capabilities.

**Key Features:**
- 3-node Kubernetes cluster
- Serverless functions (OpenFaaS)
- Load balancing (MetalLB)
- Ingress routing (NGINX)
- GitOps with ArgoCD

**Technologies:** Kubernetes, OpenFaaS, Helm, ArgoCD

**Time to Deploy:** 4-6 hours

---

### 3. [Database Cluster](./03-db-cluster.md)
High-availability database with automatic failover and replication.

**Key Features:**
- MongoDB replica set or PostgreSQL with Patroni
- Distributed consensus (etcd)
- Automated backups via serverless functions
- ETL pipeline support

**Technologies:** MongoDB/PostgreSQL, Patroni, etcd

**Time to Deploy:** 3-5 hours

---

### 4. [AI/ML Workbench](./04-aiml-workbench.md)
Local LLM development and machine learning experimentation.

**Key Features:**
- Local LLM inference (no API costs)
- Vector search and embeddings
- RAG (Retrieval-Augmented Generation)
- AI agents with tool use
- Model fine-tuning (LoRA)
- GPU acceleration

**Technologies:** Ollama, ChromaDB, LangChain, Jupyter, MCP

**Time to Deploy:** 3-4 hours (+ GPU passthrough setup)

---

### 5. [Security Lab](./05-security-lab.md)
Isolated penetration testing and security research environment.

**Key Features:**
- Fully isolated network (VLAN)
- Attack and defense practice
- IDS/IPS configuration
- Vulnerable targets for practice
- Active Directory pentesting

**Technologies:** Kali Linux, pfSense, Snort, Metasploit

**Time to Deploy:** 4-6 hours

## Quick Start Guide

### Step 1: Install Proxmox VE

```bash
# Download Proxmox VE ISO
# https://www.proxmox.com/en/downloads

# Install on bare metal or nested virtualization
# Configure network bridges (vmbr0 for main, vmbr1 for security lab)
```

### Step 2: Initial Configuration

```bash
# Update Proxmox
apt update && apt full-upgrade -y

# Install useful tools
apt install -y git vim htop iotop
```

### Step 3: Choose Your Path

**Option A: DevOps Focus**
1. Deploy [CI/CD Platform](./01-cicd-platform.md)
2. Deploy [K8s Platform](./02-k8s-platform.md)
3. Deploy [DB Cluster](./03-db-cluster.md)
4. Integrate all three environments

**Option B: AI/ML Focus**
1. Deploy [AI/ML Workbench](./04-aiml-workbench.md)
2. Configure GPU passthrough
3. Install Ollama and pull models
4. Build RAG applications

**Option C: Security Focus**
1. Create isolated VLAN
2. Deploy [Security Lab](./05-security-lab.md)
3. Set up Kali + pfSense + targets
4. Practice ethical hacking

**Option D: Full Stack (32GB+ RAM)**
1. Deploy all environments
2. Run concurrent workloads
3. Cross-environment integration

## Integration Examples

### CI/CD → K8s → DB Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - build
  - deploy

build:
  script:
    - docker build -t registry.local/app:${CI_COMMIT_SHA} .
    - docker push registry.local/app:${CI_COMMIT_SHA}

deploy:
  script:
    - kubectl set image deployment/app app=registry.local/app:${CI_COMMIT_SHA}
    - kubectl rollout status deployment/app
```

### Serverless DB Backup Function

```python
# Deployed on K8s, targets DB Cluster
def handle(req):
    import subprocess
    subprocess.run(["mongodump", "--host", "db-cluster:27017",
                    "--out", "/backup/$(date +%Y%m%d)"])
    return "Backup complete"
```

### AI Inference API

```python
# FastAPI on K8s, calls AI/ML Workbench
from fastapi import FastAPI
from langchain_ollama import OllamaLLM

app = FastAPI()
llm = OllamaLLM(model="llama3:8b", base_url="http://aiml-workbench:11434")

@app.post("/generate")
async def generate(prompt: str):
    return {"response": llm.invoke(prompt)}
```

## Networking Configuration

### Network Topology

```
┌──────────────────────────────────────────┐
│         Physical Network (vmbr0)         │
│              192.168.1.0/24              │
│                                          │
│  ┌──────┐  ┌─────┐  ┌─────┐  ┌───────┐ │
│  │CI/CD │  │ K8s │  │ DB  │  │ AI/ML │ │
│  └──────┘  └─────┘  └─────┘  └───────┘ │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│     Isolated Security VLAN (vmbr1)       │
│              10.10.10.0/24               │
│                                          │
│  ┌──────┐  ┌─────────┐  ┌──────────┐   │
│  │Kali  │  │pfSense  │  │ Targets  │   │
│  └──────┘  └─────────┘  └──────────┘   │
└──────────────────────────────────────────┘
```

## Backup Strategy

### Critical Data
- VM configurations: `/etc/pve/qemu-server/`
- LXC configurations: `/etc/pve/lxc/`
- Git repositories (CI/CD platform)
- Database dumps (DB cluster)
- Fine-tuned models (AI/ML workbench)
- Jupyter notebooks

### Backup Methods

```bash
# Proxmox VM backup
vzdump <vmid> --mode snapshot --storage <backup-location>

# Database backup (automated via serverless function)
mongodump --host db-cluster:27017 --out /backup/$(date +%Y%m%d)

# Git backup
tar -czf git-repos-backup.tar.gz /var/opt/gitlab/git-data/repositories/
```

## Monitoring & Observability

### Metrics Collection
- **Proxmox:** Built-in monitoring dashboard
- **Kubernetes:** Prometheus + Grafana
- **Databases:** MongoDB/PostgreSQL exporters
- **AI/ML:** GPU metrics (nvidia-smi), Ollama API stats

### Logging
- **Centralized logging:** ELK stack (optional)
- **Application logs:** Kubernetes logs via kubectl
- **System logs:** journalctl on VMs/LXC

## Troubleshooting

### Common Issues

**Out of Memory:**
- Shut down unused environments
- Reduce VM/LXC memory allocation
- Enable memory ballooning
- Add swap (not recommended for production)

**Storage Full:**
- Clean up old Docker images: `docker system prune -a`
- Remove old backups
- Clear Kubernetes unused PVs
- Archive or delete old models (AI/ML)

**Network Issues:**
- Check Proxmox bridge configuration
- Verify firewall rules (pfSense, Proxmox)
- Test with `ping`, `traceroute`
- Check Kubernetes CNI plugin status

**GPU Not Detected (AI/ML):**
- Verify IOMMU enabled in BIOS
- Check PCI passthrough configuration
- Ensure NVIDIA drivers installed
- Run `nvidia-smi` to test

## Learning Paths

### DevOps Engineer
1. Master CI/CD Platform - Build pipelines
2. Learn Kubernetes - Deploy applications
3. Understand databases - HA and backups
4. Integrate serverless - Automate workflows

### AI/ML Developer
1. Set up AI/ML Workbench
2. Experiment with local LLMs (Ollama)
3. Build RAG systems (ChromaDB + LangChain)
4. Fine-tune models for specific tasks
5. Deploy inference APIs to K8s

### Security Professional
1. Deploy Security Lab
2. Practice reconnaissance (Nmap, enum4linux)
3. Exploit vulnerabilities (Metasploit)
4. Configure IDS/IPS (Snort on pfSense)
5. Secure environments (hardening, monitoring)

## Cost Analysis

### Hardware Investment
- **Entry Level (16GB RAM):** ~$500-800 (used server or workstation)
- **Mid-Range (32GB RAM):** ~$1,000-1,500 (Ryzen/Intel + RAM + SSD)
- **High-End (64GB + GPU):** ~$2,000-3,000 (RTX 4080 + 64GB DDR5)

### Operational Costs
- **Electricity:** ~$20-40/month (24/7 operation)
- **Internet:** Existing connection (optional static IP: +$10-20/month)
- **Licenses:** $0 (all open-source software)

### ROI Benefits
- **Learning:** Hands-on experience worth thousands in courses
- **Certifications:** Practice environment for OSCP, CKA, etc.
- **Projects:** Portfolio-ready deployments
- **Privacy:** No cloud costs, complete data ownership

## Contributing

This is a personal learning repository. Feel free to:
- Fork and customize for your needs
- Share improvements or alternative approaches
- Report issues or suggest enhancements

## Resources

### Documentation
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitLab Documentation](https://docs.gitlab.com/)
- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/docs/)
- [Kali Linux Documentation](https://www.kali.org/docs/)

### Communities
- [r/homelab](https://reddit.com/r/homelab) - Home lab enthusiasts
- [r/proxmox](https://reddit.com/r/proxmox) - Proxmox community
- [r/kubernetes](https://reddit.com/r/kubernetes) - K8s discussions
- [r/LocalLLaMA](https://reddit.com/r/LocalLLaMA) - Local LLM community
- [r/netsec](https://reddit.com/r/netsec) - Network security

### YouTube Channels
- **Techno Tim** - Homelab tutorials
- **NetworkChuck** - Networking and security
- **Christian Lempa** - DevOps and containers
- **Jeff Geerling** - Raspberry Pi and homelab
- **Lawrence Systems** - pfSense and networking

## License

This project documentation is provided as-is for educational purposes. All referenced software retains its original licenses.

## Disclaimer

**Security Lab Warning:** The security lab is for authorized educational purposes only. Always obtain proper authorization before testing security of any system. Unauthorized access to computer systems is illegal.

**AI/ML Notice:** Running local LLMs requires significant computational resources. Ensure your hardware meets requirements before deployment.

---

**Last Updated:** 2025-12-30

**Author:** Zakaria Statistics

**Repository:** https://github.com/zakaria-statistics/proxmox-infra-projects
