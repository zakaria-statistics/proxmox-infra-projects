# Kubernetes Concepts Roadmap
## Understanding Dependencies, Interactions & Mechanisms

This roadmap reveals how Kubernetes concepts build on each other. Master the foundations first, then understand how higher-level abstractions interact with them.

---

## Learning Philosophy: The Dependency Chain

```
Managed Abstraction/Tool
  ↓ (requires/uses)
Native K8s Resources
  ↓ (interacts with)
Lower-level Resources
  ↓ (inspect/debug)
kubectl commands
```

**Goal:** Understand what each concept needs, what it creates, and how to debug when things break.

---

## Level 0: Foundation Layer
**Master these first - everything else depends on them**

### 1. Pod
- **What it is:** Smallest deployable unit, runs containers
- **Dependencies:** Container runtime (containerd), CNI
- **Creates:** Containers in shared network namespace
- **Inspect:** `kubectl get pods`, `kubectl describe pod <name>`

### 2. Namespace
- **What it is:** Virtual cluster for isolation
- **Dependencies:** None (cluster primitive)
- **Used by:** Almost everything (scoping mechanism)
- **Inspect:** `kubectl get ns`, `kubectl get all -n <namespace>`

### 3. Labels & Selectors
- **What it is:** Key-value metadata for grouping/selecting resources
- **Dependencies:** None
- **Used by:** Services, Deployments, ReplicaSets, HPA, NetworkPolicies
- **Inspect:** `kubectl get pods --show-labels`, `kubectl get pods -l app=myapp`

---

## Level 1: Workload Management
**Build on Pods to add resilience and scaling**

### 4. ReplicaSet
```
ReplicaSet
  ↓ ensures
N identical Pods exist (using label selectors)
  ↓ if pod dies
Creates replacement automatically
```
- **Dependencies:** Pods, Labels/Selectors
- **Inspect:** `kubectl get rs`, `kubectl describe rs <name>`
- **Rarely used directly** - Deployments create these

### 5. Deployment
```
Deployment
  ↓ creates/manages
ReplicaSet
  ↓ creates/manages
Pods
```
- **Dependencies:** ReplicaSets, Pods
- **Adds:** Rolling updates, rollback, declarative updates
- **Inspect:**
  - `kubectl get deployment`
  - `kubectl rollout status deployment/<name>`
  - `kubectl get rs` (see ReplicaSets it created)

**Learning Exercise:** Deploy something → watch it create ReplicaSet → see Pods appear

---

## Level 2: Networking Stack
**Expose Pods to network traffic**

### 6. Service (ClusterIP)
```
Service (type: ClusterIP)
  ↓ uses label selector to find
Pods (backend endpoints)
  ↓ provides
Stable virtual IP inside cluster
  ↓ load balances to
Pod IPs
```
- **Dependencies:** Pods, Labels, kube-proxy
- **Creates:** Endpoints object (IP:port list of matching pods)
- **Inspect:**
  - `kubectl get svc`
  - `kubectl get endpoints <svc-name>` (see actual pod IPs)
  - `kubectl describe svc <name>`

### 7. Service (NodePort)
```
Service (type: NodePort)
  ↓ builds on
ClusterIP service
  ↓ additionally exposes
Port on every Node's IP
```
- **Dependencies:** ClusterIP service
- **Range:** 30000-32767
- **Inspect:** `kubectl get svc -o wide`

### 8. Service (LoadBalancer)
```
Service (type: LoadBalancer)
  ↓ builds on
NodePort service
  ↓ triggers external controller
MetalLB (in your cluster)
  ↓ assigns
External IP from IPAddressPool
  ↓ routes to
NodePorts → Pods
```
- **Dependencies:** NodePort, External controller (MetalLB/cloud provider)
- **Your cluster:** MetalLB provides this
- **Inspect:**
  - `kubectl get svc` (see EXTERNAL-IP)
  - `kubectl get ipaddresspool -n metallb-system`
  - `kubectl describe svc <name>`

### 9. Ingress
```
Ingress Resource (rules)
  ↓ consumed by
Ingress Controller (nginx in your cluster)
  ↓ configures
nginx reverse proxy
  ↓ routes HTTP/HTTPS to
Services (by hostname/path)
  ↓ which route to
Pods
```
- **Dependencies:** Ingress Controller, Services
- **Adds:** HTTP routing, TLS termination, virtual hosting
- **Your cluster:** ingress-nginx namespace
- **Inspect:**
  - `kubectl get ingress`
  - `kubectl describe ingress <name>`
  - `kubectl get svc -n ingress-nginx` (controller's LoadBalancer)

**The Full Stack:**
```
Internet → MetalLB External IP → Ingress Controller (nginx)
  → Ingress Rules → Service → Pods
```

---

## Level 3: Storage Abstraction
**Persistent data for Pods**

### 10. StorageClass
```
StorageClass
  ↓ defines
Provisioner (local-path-provisioner in your cluster)
  ↓ plus
Parameters (where to store, how)
```
- **Dependencies:** Storage provisioner (DaemonSet/Controller)
- **Your cluster:** local-path-provisioner
- **Inspect:**
  - `kubectl get storageclass`
  - `kubectl describe sc local-path`

### 11. PersistentVolumeClaim (PVC)
```
PVC (request for storage)
  ↓ references
StorageClass
  ↓ triggers
Provisioner to create
  ↓
PersistentVolume (PV)
```
- **Dependencies:** StorageClass
- **Creates:** PV (if dynamic provisioning)
- **Inspect:**
  - `kubectl get pvc`
  - `kubectl describe pvc <name>` (see which PV it's bound to)

### 12. PersistentVolume (PV)
```
PV (actual storage)
  ↓ bound to
PVC
  ↓ mounted in
Pod (via volumeMounts)
```
- **Created by:** Provisioner (dynamic) or admin (static)
- **Inspect:**
  - `kubectl get pv`
  - `kubectl describe pv <name>` (see node path for local-path)

**The Full Stack:**
```
StorageClass → Provisioner → PV ← PVC ← Pod
```

**Learning Exercise:** Create PVC → watch PV auto-created → mount in Pod → inspect node filesystem

---

## Level 4: Autoscaling & Resource Management
**Dynamic scaling based on metrics**

### 13. Resource Requests/Limits
```
Pod spec (resources: requests/limits)
  ↓ used by
Scheduler (placement decisions)
  ↓ and
Kubelet (enforcement)
  ↓ and
HPA (utilization calculation)
```
- **Dependencies:** None, but required for HPA
- **Requests:** Guaranteed resources
- **Limits:** Maximum resources
- **Inspect:** `kubectl describe pod <name>` (see Requests/Limits section)

### 14. Metrics Server
```
Metrics Server (Deployment in kube-system)
  ↓ scrapes from
Kubelet on each node (cAdvisor)
  ↓ provides
Resource metrics API
  ↓ consumed by
HPA, kubectl top
```
- **Dependencies:** Kubelet
- **Your cluster:** Running in kube-system
- **Inspect:**
  - `kubectl top nodes`
  - `kubectl top pods -n <namespace>`
  - `kubectl get deployment metrics-server -n kube-system`

### 15. HorizontalPodAutoscaler (HPA)
```
HPA
  ↓ watches
Metrics Server API
  ↓ calculates desired replicas based on
Target metrics (CPU/memory utilization)
  ↓ scales
Deployment/ReplicaSet
  ↓ which creates/deletes
Pods
```
- **Dependencies:** Metrics Server, Deployment, Resource Requests
- **Formula:** `desired = ceil(current * (currentMetric / targetMetric))`
- **Your cluster:** php-apache-hpa in hpa-demo
- **Inspect:**
  - `kubectl get hpa -n hpa-demo`
  - `kubectl describe hpa <name>` (see current metrics, events)
  - `kubectl get deployment <name>` (see replica changes)

**The Full Stack:**
```
cAdvisor → Kubelet → Metrics Server → HPA → Deployment → ReplicaSet → Pods
```

**Learning Exercise:** Load test → watch CPU rise → see HPA scale up → remove load → watch scale down

---

## Level 5: Cluster Networking Foundation
**How Pods communicate**

### 16. CNI (Container Network Interface)
```
CNI Plugin (Calico in your cluster)
  ↓ runs as
DaemonSet (calico-node on every node)
  ↓ configures
Pod network interfaces
  ↓ assigns
IP addresses to Pods
  ↓ manages
Routing between nodes
```
- **Dependencies:** None (cluster foundation)
- **Your cluster:** Calico v3.26.1
- **Inspect:**
  - `kubectl get pods -n kube-system -l k8s-app=calico-node`
  - `kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'`
  - `ip route` on nodes (see pod network routes)

### 17. kube-proxy
```
kube-proxy (DaemonSet on every node)
  ↓ watches
Service and Endpoints objects
  ↓ configures
iptables/ipvs rules
  ↓ implements
Service virtual IP routing
```
- **Dependencies:** Services
- **How it works:** Intercepts traffic to ClusterIP, redirects to pod IPs
- **Inspect:**
  - `kubectl get pods -n kube-system -l k8s-app=kube-proxy`
  - `iptables-save | grep <service-name>` on nodes

**The Full Stack:**
```
CNI Plugin → Pod networking
kube-proxy → Service networking
```

---

## Advanced Topics (Level 6+)

### ConfigMaps & Secrets
- **Dependencies:** Pods (consumers)
- **Used by:** Pods via env vars or volume mounts
- **Inspect:** `kubectl get cm`, `kubectl get secrets`

### Jobs & CronJobs
- **Dependencies:** Pods
- **Creates:** Pods (run-to-completion)
- **Inspect:** `kubectl get jobs`, `kubectl get cronjobs`

### StatefulSets
- **Dependencies:** Pods, Headless Service, PVCs
- **Adds:** Stable network identity, ordered deployment
- **Inspect:** `kubectl get statefulset`

### DaemonSets
- **Dependencies:** Pods
- **Ensures:** One pod per node
- **Examples:** CNI, kube-proxy, MetalLB speaker
- **Inspect:** `kubectl get daemonset -A`

### NetworkPolicies
- **Dependencies:** CNI with policy support (Calico has this)
- **Controls:** Pod-to-pod traffic (firewall rules)
- **Inspect:** `kubectl get networkpolicy`

---

## Practical Learning Path

### Week 1: Foundation
1. **Pods & Labels**
   - Create pods manually
   - Use labels to organize
   - Practice selectors

2. **Deployments**
   - Deploy app
   - Scale manually
   - Rolling update
   - Rollback
   - Inspect ReplicaSets created

### Week 2: Networking
3. **Services (ClusterIP)**
   - Expose deployment
   - Test from another pod
   - Inspect endpoints

4. **Services (LoadBalancer)**
   - Expose externally
   - See MetalLB assign IP
   - Test from outside cluster

5. **Ingress**
   - Create routing rules
   - Add multiple backends
   - Test host-based routing

### Week 3: Storage
6. **PVC/PV**
   - Request storage
   - Mount in pod
   - Verify data persistence
   - Find PV on node filesystem

### Week 4: Autoscaling (Current)
7. **HPA**
   - Deploy with resource requests
   - Create HPA
   - Load test and observe
   - Tune scale-up/down behavior

### Week 5: Deep Dive
8. **CNI & Networking**
   - Inspect pod IPs
   - Trace packet flow
   - Understand iptables rules

9. **Advanced Workloads**
   - StatefulSets
   - DaemonSets
   - Jobs/CronJobs

---

## Debugging Cheat Sheet

### When HPA doesn't work:
1. `kubectl get hpa` - check metrics showing?
2. `kubectl top pods` - metrics server working?
3. `kubectl describe hpa` - check events
4. `kubectl get deployment` - check resource requests set?

### When Service doesn't route:
1. `kubectl get endpoints <svc>` - are pods listed?
2. `kubectl get pods -l <selector>` - do pods exist with matching labels?
3. `kubectl describe svc` - check selector matches pods

### When LoadBalancer stuck pending:
1. `kubectl get svc` - EXTERNAL-IP shows <pending>?
2. `kubectl get pods -n metallb-system` - MetalLB running?
3. `kubectl get ipaddresspool -n metallb-system` - IPs available?

### When PVC stuck pending:
1. `kubectl get pvc` - status pending?
2. `kubectl get storageclass` - provisioner installed?
3. `kubectl describe pvc` - check events

### When Ingress doesn't route:
1. `kubectl get ingress` - ADDRESS assigned?
2. `kubectl describe ingress` - backend services exist?
3. `kubectl get svc -n ingress-nginx` - controller has external IP?
4. `kubectl logs -n ingress-nginx <controller-pod>` - check routing logs

---

## Mental Models

### The Service Ladder
```
ClusterIP (internal only)
  ↓ adds external node port
NodePort (accessible on node IPs)
  ↓ adds external load balancer
LoadBalancer (single external IP)
  ↓ adds HTTP routing
Ingress (host/path-based routing)
```

### The Storage Ladder
```
Pod ephemeral storage (dies with pod)
  ↓ add persistence
emptyDir (shared between containers, dies with pod)
  ↓ add persistence
hostPath (survives pod deletion, node-local)
  ↓ add abstraction
PV/PVC (abstracts storage backend)
  ↓ add dynamic provisioning
StorageClass (auto-creates PVs)
```

### The Scaling Ladder
```
Single Pod (no resilience)
  ↓ add replicas
ReplicaSet (fixed number)
  ↓ add declarative updates
Deployment (rolling updates)
  ↓ add auto-scaling
HPA (scales based on metrics)
```

---

## Your Cluster's Full Stack Map

```
Application Layer:
  Ingress (HTTP routing) → Services → Deployments → Pods

Scaling Layer:
  HPA → Metrics Server → Pods (resource requests)

Storage Layer:
  PVC → StorageClass → local-path-provisioner → PV → Pod

Network Layer:
  MetalLB (external IPs) → kube-proxy (service routing) → Calico (pod networking)

Foundation:
  kubelet → containerd → Linux namespaces/cgroups
```

---

## Next Steps

1. **Complete HPA tutorial** (you're here)
   - Load test php-apache
   - Observe scaling behavior
   - Experiment with different thresholds

2. **Practice NetworkPolicies**
   - Create isolated namespaces
   - Allow specific pod-to-pod traffic

3. **Build a complete app stack**
   - Frontend (Deployment + LoadBalancer)
   - Backend (Deployment + ClusterIP)
   - Database (StatefulSet + PVC)
   - Ingress (route to frontend)
   - HPA (auto-scale backend)

4. **Learn Helm** (managed tool layer)
   - Understand what K8s resources charts create
   - Practice `helm template` to see native YAML

---

## Remember

> **Every managed tool/abstraction ultimately creates native Kubernetes resources.**
>
> When debugging, always trace down to the native layer:
> - What resources does this create?
> - What native APIs does it use?
> - How would I do this manually without the tool?

This understanding separates Kubernetes practitioners from Kubernetes experts.