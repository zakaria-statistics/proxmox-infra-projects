# Kubernetes Platform Implementation Guide

## Project Timeline Overview

**Total Estimated Time: 4-6 hours** (depending on download speeds and experience)

### Phase Breakdown
- **Phase 1**: VM Creation (30 min)
- **Phase 2**: OS Preparation (45 min)
- **Phase 3**: Kubernetes Installation (1-2 hours)
- **Phase 4**: Cluster Initialization (30 min)
- **Phase 5**: Networking Setup (45 min)
- **Phase 6**: Add-ons Installation (1-2 hours)
- **Phase 7**: Verification & Testing (30 min)

---

## Prerequisites Checklist

- [ ] Proxmox VE installed and accessible
- [ ] Ubuntu 22.04 LTS ISO uploaded to Proxmox
- [ ] Network connectivity (internet access for package downloads)
- [ ] IP addresses planned:
  - Control Plane: 192.168.11.201
  - Worker 1: 192.168.11.202
  - Worker 2: 192.168.11.203
  - MetalLB Pool: 192.168.11.240-250

---

## Phase 1: VM Creation (Run from Proxmox Host)

**Timeline: 30 minutes**

### What We're Doing
Creating 3 virtual machines that will form our Kubernetes cluster. We need VMs (not containers) because Kubernetes requires full kernel access for managing container runtimes, networking, and storage.

### Why These Resources?
- **Control Plane (2GB/2CPU)**: Runs Kubernetes API, scheduler, and etcd database
- **Workers (3GB/3CPU each)**: Run your actual applications with overhead for K8s agents

Run: `./scripts/01-create-vms.sh`

**What happens:**
1. Creates 3 VMs with IDs 201, 202, 203
2. Configures network adapters on vmbr0 (your main bridge)
3. Sets up virtual disks for each node
4. Configures boot order and BIOS settings

**Manual Steps After:**
1. Attach Ubuntu ISO to each VM
2. Start VMs and install Ubuntu Server
3. Configure static IPs during installation:
   - k8s-control: 192.168.11.201
   - k8s-worker-01: 192.168.11.202
   - k8s-worker-02: 192.168.11.203
4. Enable SSH during installation
5. Create user account (recommend: k8sadmin)

---

## Phase 2: OS Preparation (Run on ALL 3 VMs)

**Timeline: 45 minutes**

### What We're Doing
Preparing the operating system with kernel settings and modules required for Kubernetes networking and containerization.

### Why Each Step?

**Disable Swap:**
- Kubernetes requires swap off for predictable performance
- Containers should use memory limits, not swap

**Load Kernel Modules:**
- `overlay`: Enables overlay filesystem for container layers
- `br_netfilter`: Allows iptables to see bridged network traffic

**Sysctl Settings:**
- `ip_forward`: Enables packet forwarding between network interfaces
- `bridge-nf-call-iptables`: Ensures bridged traffic goes through iptables rules

Run on each VM: `./scripts/02-prepare-os.sh`

**What happens:**
1. Updates system packages
2. Disables swap permanently
3. Configures kernel modules for networking
4. Sets up IP forwarding for pod communication
5. Installs basic utilities (curl, apt-transport-https)

---

## Phase 3: Kubernetes Installation (Run on ALL 3 VMs)

**Timeline: 1-2 hours**

### What We're Doing
Installing the container runtime (containerd) and Kubernetes components on each node.

### Why Containerd?
- Lightweight container runtime (simpler than Docker)
- Industry standard, directly supported by Kubernetes
- No unnecessary daemon overhead

### Why These Components?
- **kubelet**: Node agent that manages containers
- **kubeadm**: Tool to bootstrap the cluster
- **kubectl**: CLI to interact with Kubernetes

Run on each VM: `./scripts/03-install-kubernetes.sh`

**What happens:**
1. Installs containerd container runtime
2. Configures containerd with systemd cgroup driver
3. Adds Kubernetes package repository (v1.28 - stable)
4. Installs kubelet, kubeadm, kubectl
5. Holds packages to prevent accidental upgrades

**Version Note:** We're using v1.28 as it's a stable LTS release

---

## Phase 4: Cluster Initialization (Control Plane Only)

**Timeline: 30 minutes**

### What We're Doing
Initializing the Kubernetes control plane which will manage the entire cluster.

### Why Each Flag?

**--pod-network-cidr=10.244.0.0/16:**
- Defines IP range for pods (containers)
- Separated from your physical network (192.168.11.x)
- Required for Flannel/Calico CNI plugins

**--apiserver-advertise-address:**
- IP where other nodes will reach the API server
- Must be the control plane's static IP (192.168.11.201)

Run on control plane only: `./scripts/04-init-control-plane.sh`

**What happens:**
1. Initializes Kubernetes control plane
2. Generates certificates for secure communication
3. Starts etcd database (cluster state storage)
4. Configures kubectl for the current user
5. Outputs join command for worker nodes (SAVE THIS!)

**Important:** Copy the `kubeadm join` command output - you'll need it in Phase 5!

---

## Phase 5: Join Worker Nodes (Workers Only)

**Timeline: 20 minutes**

### What We're Doing
Connecting worker nodes to the control plane so they can receive workloads.

### How It Works
The join command contains:
- **Token**: Temporary credential for joining
- **CA Cert Hash**: Verifies control plane identity (prevents MITM attacks)
- **API Server IP**: Where to connect

**First**, on control plane, run:
```bash
./scripts/05-get-join-command.sh
```

**Then**, on EACH worker node, run the output command:
```bash
kubeadm join 192.168.11.201:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

**What happens:**
1. Worker authenticates with control plane
2. Downloads cluster certificates
3. Starts kubelet service
4. Registers node with cluster

**Verify:** Run on control plane:
```bash
kubectl get nodes
```
You should see all 3 nodes (will be "NotReady" until CNI is installed)

---

## Phase 6a: Install CNI Plugin (Control Plane)

**Timeline: 15 minutes**

### What We're Doing
Installing Container Network Interface to enable pod-to-pod communication.

### Why Calico?
- Provides pod networking across nodes
- Implements network policies (firewall rules between pods)
- Production-grade, widely used

### How It Works
- Creates a virtual network overlay
- Each pod gets an IP from 10.244.0.0/16 range
- Routes traffic between pods across different nodes

Run on control plane: `./scripts/06a-install-calico.sh`

**What happens:**
1. Deploys Calico pods to all nodes
2. Configures virtual network interfaces
3. Sets up routing between nodes

**Verify:** Nodes should now show "Ready" status:
```bash
kubectl get nodes
```

---

## Phase 6b: Install MetalLB (Control Plane)

**Timeline: 15 minutes**

### What We're Doing
Installing a load balancer to expose Kubernetes services on your local network.

### Why MetalLB?
- Cloud providers give you LoadBalancers automatically
- On bare-metal/Proxmox, we need MetalLB
- Assigns real IPs from your network to services

### How It Works
- You define an IP pool (192.168.11.240-250)
- When you create a LoadBalancer service, MetalLB assigns an IP
- Uses Layer 2 mode (ARP) to announce IPs on your network

Run on control plane: `./scripts/06b-install-metallb.sh`

**What happens:**
1. Deploys MetalLB controller and speakers
2. Configures IP address pool
3. Sets up L2 advertisement mode

---

## Phase 6c: Install Ingress NGINX (Control Plane)

**Timeline: 15 minutes**

### What We're Doing
Installing an HTTP/HTTPS router to expose web applications.

### Why Ingress?
- Exposes multiple services through a single IP
- Provides hostname-based routing (app1.example.com → service1)
- SSL/TLS termination
- Path-based routing (/api → api-service, / → frontend-service)

### How It Works
```
Internet → Ingress (192.168.11.240) → Routes to Services → Pods
```

Run on control plane: `./scripts/06c-install-ingress.sh`

**What happens:**
1. Deploys NGINX Ingress Controller
2. Creates LoadBalancer service (gets IP from MetalLB)
3. Ready to route HTTP/HTTPS traffic

**Verify:** Check LoadBalancer IP:
```bash
kubectl get svc -n ingress-nginx
```

---

## Phase 6d: Install Storage Provisioner (Control Plane)

**Timeline: 10 minutes**

### What We're Doing
Installing automatic persistent volume provisioner.

### Why Local Path Provisioner?
- Automatically creates persistent volumes on node disk
- No need for NFS or external storage (good for homelab)
- Uses local SSD/HDD on each worker node

### How It Works
- Application requests storage (PersistentVolumeClaim)
- Provisioner creates directory on worker node
- Data persists even if pod restarts

Run on control plane: `./scripts/06d-install-storage.sh`

**What happens:**
1. Deploys local-path-provisioner
2. Sets as default storage class
3. Creates storage directories on workers

---

## Phase 6e: Install OpenFaaS (Optional - Control Plane)

**Timeline: 20 minutes**

### What We're Doing
Installing serverless functions platform on Kubernetes.

### Why OpenFaaS?
- Run code without managing servers
- Auto-scaling based on load
- Great for: API endpoints, scheduled tasks, event processing

### Use Cases
- Database backups triggered by cron
- Image processing (upload → resize → store)
- API microservices without full deployment
- ML model inference endpoints

Run on control plane: `./scripts/06e-install-openfaas.sh`

**What happens:**
1. Installs arkade (package manager)
2. Deploys OpenFaaS core components
3. Sets up gateway and function executor
4. Generates admin password

**Access:** The script outputs the gateway URL and credentials

---

## Phase 7: Verification & Testing

**Timeline: 30 minutes**

### What We're Doing
Verifying cluster health and deploying a test application.

Run on control plane: `./scripts/07-verify-cluster.sh`

**What this checks:**
1. All nodes are Ready
2. All system pods are Running
3. DNS is working (CoreDNS)
4. Network connectivity between pods
5. Storage provisioning works

### Deploy Test Application
```bash
./scripts/08-deploy-test-app.sh
```

**What this deploys:**
- Simple nginx web server
- Exposed via Ingress
- Uses persistent storage
- Scaled to 3 replicas across workers

**Access:** Visit `http://<INGRESS_IP>` in your browser

---

## Post-Installation

### Enable kubectl Autocomplete
```bash
echo 'source <(kubectl completion bash)' >>~/.bashrc
```

### Install Helm (Package Manager)
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Set up Monitoring (Optional)
```bash
./scripts/optional/install-monitoring.sh
```
Installs Prometheus + Grafana for cluster metrics

---

## Common Issues & Solutions

### Nodes Stuck in "NotReady"
**Cause:** CNI not installed or not running
**Solution:**
```bash
kubectl get pods -n kube-system  # Check calico pods
kubectl logs -n kube-system <calico-pod>  # Check logs
```

### Pods Stuck in "Pending"
**Cause:** Insufficient resources or scheduling constraints
**Solution:**
```bash
kubectl describe pod <pod-name>  # Check Events section
```

### "connection refused" to API Server
**Cause:** Firewall blocking port 6443
**Solution:**
```bash
sudo ufw allow 6443/tcp
```

### MetalLB Not Assigning IPs
**Cause:** IP pool conflicts with network DHCP
**Solution:** Ensure 192.168.11.240-250 is outside DHCP range

---

## Useful Commands Reference

### Cluster Status
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces
```

### Resource Management
```bash
kubectl top nodes          # Node CPU/memory usage
kubectl top pods -A        # Pod resource usage
kubectl describe node <name>  # Detailed node info
```

### Troubleshooting
```bash
kubectl logs <pod-name>              # Pod logs
kubectl logs <pod-name> --previous   # Logs from crashed pod
kubectl exec -it <pod-name> -- bash  # Shell into pod
kubectl describe pod <pod-name>      # Detailed pod info
```

### Cleanup
```bash
kubectl delete pod <name>
kubectl delete deployment <name>
kubectl delete service <name>
```

---

## Next Steps After Setup

1. **Integrate with CI/CD** - Connect GitLab/Jenkins for automated deployments
2. **Set up Monitoring** - Install Prometheus/Grafana stack
3. **Configure Backups** - Set up etcd backup automation
4. **Deploy Real Applications** - Migrate apps from docker-lxc
5. **Implement GitOps** - Install ArgoCD for declarative deployments

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│            Proxmox Host (192.168.11.50)         │
│                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌────────┐│
│  │ k8s-control  │  │k8s-worker-01 │  │worker-02││
│  │  .11.201     │  │   .11.202    │  │ .11.203 ││
│  │  2GB/2CPU    │  │  3GB/3CPU    │  │3GB/3CPU ││
│  │              │  │              │  │         ││
│  │ ┌──────────┐ │  │ ┌──────────┐ │  │┌───────┐││
│  │ │API Server│ │  │ │  Pods    │ │  ││ Pods  │││
│  │ │Scheduler │ │  │ │          │ │  ││       │││
│  │ │etcd      │ │  │ │          │ │  ││       │││
│  │ └──────────┘ │  │ └──────────┘ │  │└───────┘││
│  └──────────────┘  └──────────────┘  └────────┘│
│         │                   │              │     │
│         └───────────────────┴──────────────┘     │
│                      │                           │
└──────────────────────┼───────────────────────────┘
                       │
                   vmbr0 Bridge
                       │
                ┌──────┴────────┐
                │  Ingress NGINX │
                │ 192.168.11.240 │
                └───────┬────────┘
                        │
                   Internet/LAN
```

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review script outputs for error messages
3. Verify all prerequisites are met
4. Check Kubernetes logs: `journalctl -u kubelet -f`
