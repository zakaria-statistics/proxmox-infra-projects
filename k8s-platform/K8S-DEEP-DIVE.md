# Kubernetes Deep Dive - Complete Management & Debugging Guide

## Philosophy: Learn by Inspecting Native Resources

**Every managed tool creates native K8s resources. Always inspect what's happening underneath.**

---

## Part 1: Essential Debugging Toolset

### Core Tools Stack

```bash
# 1. kubectl - Primary K8s CLI
kubectl version --client

# 2. k9s - Terminal UI for K8s (highly recommended)
curl -sS https://webinstall.dev/k9s | bash

# 3. stern - Multi-pod log tailing
wget https://github.com/stern/stern/releases/download/v1.28.0/stern_1.28.0_linux_amd64.tar.gz
tar -xzf stern_1.28.0_linux_amd64.tar.gz
sudo mv stern /usr/local/bin/

# 4. kubectx/kubens - Context and namespace switching
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

# 5. dive - Container image inspector
wget https://github.com/wagoodman/dive/releases/download/v0.11.0/dive_0.11.0_linux_amd64.tar.gz
tar -xzf dive_0.11.0_linux_amd64.tar.gz
sudo mv dive /usr/local/bin/

# 6. kubectl plugins via krew
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Install useful plugins
kubectl krew install tree        # Resource hierarchy viewer
kubectl krew install neat        # Clean YAML output
kubectl krew install ctx         # Context switcher
kubectl krew install ns          # Namespace switcher
kubectl krew install tail        # Pod log tailing
kubectl krew install debug       # Debug containers
kubectl krew install resource-capacity  # Resource usage
```

---

## Part 2: Understanding the Resource Hierarchy

### The Complete K8s Object Model

```
Cluster (Physical)
├── Nodes (VMs/Bare Metal)
│   ├── kubelet (node agent)
│   ├── kube-proxy (networking)
│   └── Container Runtime (containerd/docker)
│
├── Namespaces (Logical Isolation)
│   ├── Workloads
│   │   ├── Pod (smallest unit)
│   │   ├── ReplicaSet (maintains pod replicas)
│   │   ├── Deployment → ReplicaSet → Pods
│   │   ├── StatefulSet → Pods (with stable identity)
│   │   ├── DaemonSet → Pods (one per node)
│   │   ├── Job → Pods (run to completion)
│   │   └── CronJob → Jobs → Pods
│   │
│   ├── Services & Networking
│   │   ├── Service (ClusterIP, NodePort, LoadBalancer)
│   │   ├── Ingress → Service → Pods
│   │   ├── NetworkPolicy (firewall rules)
│   │   └── Endpoints (service backends)
│   │
│   ├── Storage
│   │   ├── PersistentVolumeClaim (PVC)
│   │   ├── PersistentVolume (PV)
│   │   ├── StorageClass (dynamic provisioning)
│   │   └── ConfigMap / Secret (config storage)
│   │
│   └── Configuration
│       ├── ConfigMap (non-sensitive data)
│       ├── Secret (sensitive data)
│       ├── ServiceAccount (pod identity)
│       ├── Role/RoleBinding (namespace RBAC)
│       └── ResourceQuota / LimitRange
│
└── Cluster-Scoped Resources
    ├── ClusterRole / ClusterRoleBinding (cluster RBAC)
    ├── PersistentVolume (not namespaced)
    ├── StorageClass
    ├── Node
    ├── Namespace
    └── CustomResourceDefinition (CRD)
```

### Inspect Everything Command

```bash
# See ALL resource types K8s supports
kubectl api-resources

# See all objects in current namespace
kubectl get all

# See EVERYTHING across all namespaces (huge output)
kubectl get all -A

# Resource hierarchy for specific deployment
kubectl tree deployment my-app
```

---

## Part 3: Deep Debugging Workflow

### Level 1: Quick Health Check

```bash
# Cluster health
kubectl cluster-info
kubectl get nodes -o wide
kubectl top nodes  # Requires metrics-server

# All resources in namespace
kubectl get all -n default

# Events (critical for debugging)
kubectl get events -n default --sort-by='.lastTimestamp'
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### Level 2: Pod Troubleshooting

```bash
# Pod status
kubectl get pods -o wide
kubectl describe pod <pod-name>

# Common failure states
kubectl get pods --field-selector=status.phase=Failed
kubectl get pods --field-selector=status.phase=Pending

# Pod logs
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>  # Multi-container pod
kubectl logs <pod-name> --previous  # Previous crashed container
stern <pod-prefix>  # Tail logs from multiple pods

# Interactive debugging
kubectl exec -it <pod-name> -- /bin/sh
kubectl exec -it <pod-name> -c <container> -- /bin/bash

# Debug with ephemeral container (K8s 1.23+)
kubectl debug <pod-name> -it --image=busybox --target=<container>

# Port forward for testing
kubectl port-forward pod/<pod-name> 8080:80
```

### Level 3: Service & Networking Debug

```bash
# Service inspection
kubectl get svc
kubectl describe svc <service-name>
kubectl get endpoints <service-name>  # See actual pod IPs

# Test service from inside cluster
kubectl run debug-pod --rm -it --image=nicolaka/netshoot -- /bin/bash
# Inside pod:
curl http://<service-name>.<namespace>.svc.cluster.local
nslookup <service-name>.<namespace>.svc.cluster.local
traceroute <pod-ip>

# Ingress debugging
kubectl get ingress
kubectl describe ingress <ingress-name>
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# NetworkPolicy impact
kubectl get networkpolicies
kubectl describe networkpolicy <name>
```

### Level 4: Storage Debugging

```bash
# PVC status
kubectl get pvc
kubectl describe pvc <pvc-name>

# PV details
kubectl get pv
kubectl describe pv <pv-name>

# StorageClass
kubectl get storageclass
kubectl describe storageclass <sc-name>

# See what's using storage
kubectl get pods -o=json | jq '.items[] | {name: .metadata.name, volumes: .spec.volumes}'

# Local path provisioner debugging (if using)
kubectl logs -n kube-system -l app=local-path-provisioner
ls -la /opt/local-path-provisioner/  # On worker nodes
```

### Level 5: Resource & Performance Debug

```bash
# Resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Resource requests/limits
kubectl describe nodes | grep -A 5 "Allocated resources"
kubectl resource-capacity

# See pod resource specs
kubectl get pods -o custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory

# Events related to resource issues
kubectl get events -A | grep -i "insufficient\|evict\|oom"
```

### Level 6: Control Plane & System Components

```bash
# Control plane health
kubectl get componentstatuses  # Deprecated but useful

# System pods
kubectl get pods -n kube-system
kubectl logs -n kube-system kube-apiserver-<node>
kubectl logs -n kube-system kube-controller-manager-<node>
kubectl logs -n kube-system kube-scheduler-<node>

# etcd health (on control plane)
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

# kubelet logs (on nodes)
sudo journalctl -u kubelet -f
sudo journalctl -u kubelet --since "10 minutes ago"
```

---

## Part 4: Managed Tools → Native Resources Mapping

### MetalLB (LoadBalancer)

```bash
# What MetalLB creates
kubectl get pods -n metallb-system
kubectl get daemonset -n metallb-system
kubectl get deployment -n metallb-system

# Configuration
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system

# How it works: Watch a service get an external IP
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer
watch kubectl get svc nginx  # See EXTERNAL-IP assignment

# Debug MetalLB
kubectl logs -n metallb-system -l app=metallb -l component=speaker
kubectl logs -n metallb-system -l app=metallb -l component=controller
```

### Local Path Provisioner (Dynamic PVs)

```bash
# What it creates
kubectl get pods -n kube-system -l app=local-path-provisioner
kubectl get storageclass local-path

# How it works: Watch dynamic PV creation
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc test-pvc
kubectl get pv  # See auto-created PV
kubectl describe pvc test-pvc

# Where data is stored (on node)
kubectl get pv <pv-name> -o jsonpath='{.spec.local.path}'
# SSH to node and check that path
```

### Ingress Controller (nginx-ingress)

```bash
# What it creates
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get deployment -n ingress-nginx

# How it works
kubectl get ingress -A
kubectl describe ingress <ingress-name>

# See nginx config generated by ingress resources
kubectl exec -n ingress-nginx <controller-pod> -- cat /etc/nginx/nginx.conf

# Debug
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=100
```

---

## Part 5: Common Failure Patterns & Solutions

### ImagePullBackOff

```bash
# Diagnose
kubectl describe pod <pod>
# Look for: "Failed to pull image" or "manifest unknown"

# Common causes:
# 1. Image doesn't exist
# 2. Private registry without imagePullSecrets
# 3. Wrong image tag
# 4. Registry authentication issue

# Fix: Use correct image or add secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass>
```

### CrashLoopBackOff

```bash
# Diagnose
kubectl logs <pod> --previous  # See why it crashed
kubectl describe pod <pod>

# Common causes:
# 1. Application error on startup
# 2. Missing environment variables
# 3. Failed health checks
# 4. Misconfigured volumes

# Interactive debug
kubectl debug <pod> -it --image=busybox --copy-to=<pod>-debug
```

### Pending Pods

```bash
# Diagnose
kubectl describe pod <pod>
# Look for: "Insufficient cpu", "Insufficient memory", "no nodes available"

# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"
kubectl top nodes

# Check taints/tolerations
kubectl describe nodes | grep Taints
```

### Service Not Reachable

```bash
# Check endpoints
kubectl get endpoints <service>
# If empty, labels don't match

# Verify labels
kubectl get pods --show-labels
kubectl get svc <service> -o yaml | grep selector -A 5

# Test DNS
kubectl run debug --rm -it --image=busybox -- nslookup <service>.<namespace>
```

---

## Part 6: Essential kubectl Commands Reference

### Context Management

```bash
kubectl config view
kubectl config get-contexts
kubectl config use-context <context>
kubectl config set-context --current --namespace=<namespace>
```

### Output Formats

```bash
kubectl get pods -o wide
kubectl get pods -o yaml
kubectl get pods -o json | jq '.items[].metadata.name'
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
```

### Filtering

```bash
kubectl get pods --field-selector=status.phase=Running
kubectl get pods -l app=nginx
kubectl get pods --all-namespaces
kubectl get all -A -l app=myapp
```

### Editing Resources

```bash
kubectl edit deployment <name>  # Edit live
kubectl patch deployment <name> -p '{"spec":{"replicas":3}}'
kubectl scale deployment <name> --replicas=5
kubectl set image deployment/<name> container=image:tag
```

### Apply vs Create

```bash
kubectl create -f manifest.yaml  # Error if exists
kubectl apply -f manifest.yaml   # Create or update (declarative)
kubectl delete -f manifest.yaml
kubectl replace -f manifest.yaml # Delete and recreate
```

---

## Part 7: Learning Path with Your Cluster

### Week 1: Master kubectl & Basic Resources

```bash
# 1. Deploy simple app
kubectl create deployment nginx --image=nginx:latest
kubectl get deployment,rs,pods
kubectl describe deployment nginx
kubectl logs -l app=nginx

# 2. Expose with service
kubectl expose deployment nginx --port=80 --type=ClusterIP
kubectl get svc nginx
kubectl get endpoints nginx

# 3. Scale it
kubectl scale deployment nginx --replicas=3
watch kubectl get pods

# 4. Update it
kubectl set image deployment/nginx nginx=nginx:1.24
kubectl rollout status deployment/nginx
kubectl rollout history deployment/nginx
kubectl rollout undo deployment/nginx

# 5. Clean up
kubectl delete deployment nginx
kubectl delete service nginx
```

### Week 2: Storage & Configuration

```bash
# 1. ConfigMaps
kubectl create configmap my-config --from-literal=key1=value1
kubectl get configmap my-config -o yaml

# 2. Secrets
kubectl create secret generic my-secret --from-literal=password=secret123
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d

# 3. PVC workflow
# Create PVC → See PV created → Use in pod → Verify data persistence
```

### Week 3: Networking Deep Dive

```bash
# 1. Service types
# ClusterIP → NodePort → LoadBalancer → Ingress

# 2. DNS resolution
# pod.namespace.svc.cluster.local

# 3. Network debugging
# Deploy netshoot pod
# Test connectivity
# Trace packet flow
```

### Week 4: Monitoring & Troubleshooting

```bash
# 1. Install metrics-server
# 2. Use kubectl top
# 3. Set up stern for log aggregation
# 4. Practice debugging scenarios
```

---

## Part 8: k9s - Your Best Friend

```bash
# Launch k9s
k9s

# Essential k9s keybindings:
# :pods        → View pods
# :svc         → View services
# :deploy      → View deployments
# :nodes       → View nodes
# /            → Filter
# l            → Logs
# d            → Describe
# e            → Edit
# s            → Shell
# <Ctrl-d>     → Delete
# :xray deploy <name> → Show related resources
# :pulses      → Resource usage
```

---

## Part 9: MCP Server for K8s Management

For IDE integration, install an MCP server that gives Claude direct access to your cluster:

```bash
# Option 1: Official Kubernetes MCP Server (stdio)
claude mcp add --transport stdio k8s -- npx -y @modelcontextprotocol/server-kubernetes \
  --kubeconfig ~/.kube/config \
  --scope project

# Option 2: Custom kubectl wrapper MCP
claude mcp add --transport stdio kubectl -- bash -c "kubectl $@" \
  --scope project
```

Then in Claude Code, you can:
- `@k8s:pod://default/nginx` - Reference specific resources
- "List all failing pods" - Query cluster state
- "Debug the nginx deployment" - Get structured debugging info

---

## Part 10: Daily Debugging Workflow

### Morning Cluster Health Check

```bash
#!/bin/bash
# Save as k8s-health-check.sh

echo "=== Cluster Info ==="
kubectl cluster-info

echo -e "\n=== Node Status ==="
kubectl get nodes

echo -e "\n=== System Pods ==="
kubectl get pods -n kube-system | grep -v Running

echo -e "\n=== Failed Pods ==="
kubectl get pods -A --field-selector=status.phase=Failed

echo -e "\n=== Recent Events ==="
kubectl get events -A --sort-by='.lastTimestamp' | tail -10

echo -e "\n=== Resource Usage ==="
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
```

### Real-time Monitoring

```bash
# Terminal 1: Watch pods
watch kubectl get pods -A

# Terminal 2: Tail all logs
stern . -A

# Terminal 3: k9s for interactive management
k9s
```

---

## Quick Reference Card

```bash
# Debugging Commands (memorize these)
kubectl get events --sort-by='.lastTimestamp'
kubectl describe <resource> <name>
kubectl logs <pod> --previous
kubectl exec -it <pod> -- sh
kubectl debug <pod> -it --image=nicolaka/netshoot --copy-to=debug
stern <pattern>

# Resource inspection
kubectl get all
kubectl tree <resource> <name>
kubectl get <resource> -o yaml | kubectl neat

# Common fixes
kubectl delete pod <pod>  # Force restart
kubectl rollout restart deployment/<name>
kubectl scale deployment/<name> --replicas=0  # Stop
kubectl scale deployment/<name> --replicas=3  # Start
```

---

## Next Steps

1. **Install tools** (script provided above)
2. **Practice with your existing cluster** in k8s-platform/
3. **Break things intentionally** and debug them
4. **Read every `kubectl describe` output** completely
5. **Use k9s daily** instead of kubectl get/describe
6. **Enable MCP server** for IDE integration

**Remember:** Every managed tool creates native resources. Always ask:
- What resources did this create?
- How do I inspect them?
- What happens if I delete them manually?
