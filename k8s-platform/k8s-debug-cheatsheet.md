# Kubernetes Debugging Cheat Sheet

## 🚨 Emergency Debugging (Memorize These)

```bash
# 1. What's broken?
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# 2. Why is this pod broken?
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous

# 3. Get inside the pod
kubectl exec -it <pod-name> -- sh

# 4. Debug with better tools
kubectl debug <pod-name> -it --image=nicolaka/netshoot --copy-to=debug

# 5. Watch everything live
k9s
```

---

## 📊 Quick Health Checks

```bash
# Cluster overview
kubectl cluster-info
kubectl get nodes
kubectl get pods -A | grep -v Running

# Failed resources
kubectl get pods -A --field-selector=status.phase=Failed
kubectl get pods -A --field-selector=status.phase=Pending

# Resource usage
kubectl top nodes
kubectl top pods -A --sort-by=cpu
```

---

## 🔍 Inspection Commands

```bash
# Hierarchy view
kubectl tree deployment <name>

# Clean output
kubectl get pod <name> -o yaml | kubectl neat

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP

# JSON queries
kubectl get pods -o json | jq '.items[].metadata.name'
```

---

## 🌐 Network Debugging

```bash
# Service → Endpoints chain
kubectl get svc <name>
kubectl get endpoints <name>
kubectl describe svc <name>

# DNS test pod
kubectl run debug --rm -it --image=nicolaka/netshoot -- /bin/bash
# Inside: curl http://<service>.<namespace>.svc.cluster.local

# Trace connectivity
kubectl exec -it <pod> -- ping <target>
kubectl exec -it <pod> -- curl -v <url>
```

---

## 💾 Storage Debugging

```bash
# PVC status
kubectl get pvc
kubectl describe pvc <name>

# See bound PV
kubectl get pv

# Which pod uses which PVC
kubectl get pods -o json | jq '.items[] | select(.spec.volumes[]?.persistentVolumeClaim) | {name: .metadata.name, pvc: .spec.volumes[].persistentVolumeClaim.claimName}'
```

---

## 📝 Logs

```bash
# Single pod
kubectl logs <pod>
kubectl logs <pod> -c <container>  # specific container
kubectl logs <pod> --previous      # previous crash

# Multiple pods
stern <pod-pattern>
stern <pod-pattern> -n <namespace>
stern . -A  # ALL pods, ALL namespaces

# Follow logs
kubectl logs -f <pod>
```

---

## 🔧 Common Fixes

```bash
# Restart deployment
kubectl rollout restart deployment/<name>

# Force pod restart
kubectl delete pod <pod>

# Scale to zero and back
kubectl scale deployment/<name> --replicas=0
kubectl scale deployment/<name> --replicas=3

# Rollback deployment
kubectl rollout undo deployment/<name>
kubectl rollout history deployment/<name>
```

---

## 🎯 Resource Management

```bash
# See what's using resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Resource requests/limits
kubectl get pods -o custom-columns=NAME:.metadata.name,CPU:.spec.containers[*].resources.requests.cpu,MEM:.spec.containers[*].resources.requests.memory

# Evicted pods
kubectl get pods -A | grep Evicted
kubectl delete pods -A --field-selector=status.phase=Failed
```

---

## 🏷️ Labels & Selectors

```bash
# Show labels
kubectl get pods --show-labels
kubectl get pods -L app,version

# Filter by label
kubectl get pods -l app=nginx
kubectl get pods -l 'env in (prod,staging)'

# Edit labels
kubectl label pod <pod> env=prod
kubectl label pod <pod> env-  # Remove label
```

---

## 🔐 RBAC Debugging

```bash
# Can I do this?
kubectl auth can-i create deployments
kubectl auth can-i get pods --as=system:serviceaccount:default:my-sa

# What can I do?
kubectl auth can-i --list

# Role bindings
kubectl get rolebindings,clusterrolebindings -A
```

---

## 📦 Image Debugging

```bash
# Image pull issues
kubectl describe pod <pod> | grep -A 10 "Events"

# Inspect image layers
dive <image:tag>

# Get image from running pod
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].image}'
```

---

## 🎨 k9s Essential Keys

```
:pods        → View pods
:deploy      → Deployments
:svc         → Services
:nodes       → Nodes
/            → Filter
l            → Logs
d            → Describe
e            → Edit
s            → Shell
<Ctrl-d>     → Delete
:xray deploy <name> → Show related resources
```

---

## 🔄 GitOps Workflow

```bash
# Edit locally
kubectl get deployment <name> -o yaml > deployment.yaml
# Edit file
kubectl apply -f deployment.yaml

# Diff before apply
kubectl diff -f deployment.yaml

# Dry run
kubectl apply -f deployment.yaml --dry-run=client
kubectl apply -f deployment.yaml --dry-run=server
```

---

## 🧪 Testing Resources

```bash
# Test deployment
kubectl create deployment test --image=nginx --dry-run=client -o yaml

# Test service
kubectl expose deployment test --port=80 --dry-run=client -o yaml

# Quick pod for testing
kubectl run tmp --image=nginx --rm -it -- /bin/sh
```

---

## 🎓 Understanding Managed Tools

### MetalLB (LoadBalancer)
```bash
kubectl get svc -A | grep LoadBalancer  # See assigned IPs
kubectl logs -n metallb-system -l component=speaker
```

### Local-Path-Provisioner (Storage)
```bash
kubectl get pv  # See auto-created volumes
kubectl get storageclass local-path -o yaml
```

### Ingress Controller
```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
kubectl exec -n ingress-nginx <pod> -- cat /etc/nginx/nginx.conf
```

---

## 💡 Pro Tips

1. **Always check events first:** `kubectl get events --sort-by='.lastTimestamp'`
2. **Use k9s for exploration:** Much faster than kubectl commands
3. **Keep stern running:** `stern . -A` in a dedicated terminal
4. **Describe everything:** `kubectl describe` gives you the full story
5. **Learn to read YAML:** Every resource is just YAML
6. **Follow the chain:** Deployment → ReplicaSet → Pod → Container
7. **Check labels:** Most issues are mismatched labels/selectors

---

## 🆘 Common Error Patterns

| Error | Check This |
|-------|-----------|
| ImagePullBackOff | `kubectl describe pod` → Image name, registry auth |
| CrashLoopBackOff | `kubectl logs <pod> --previous` → Application error |
| Pending | `kubectl describe pod` → Resources, node selectors, taints |
| Error | `kubectl logs <pod>` → Application logs |
| 0/1 Running | `kubectl describe pod` → Readiness probe failures |
| Service unreachable | `kubectl get endpoints` → Label mismatch |

---

**Print this. Keep it visible. Master these commands.**
