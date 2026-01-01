# HPA Resource Exhaustion Test

## Goal
Trigger CPU resource errors when HPA scales to 10 pods.

## Two Approaches

### **Approach 1: ResourceQuota (Recommended - Predictable)**

Creates artificial CPU limit in namespace.

```bash
# Apply quota
kubectl apply -f 06-resource-exhaustion-test.yaml

# Run load test
./04-generate-load.sh

# Watch HPA scale up
kubectl get hpa -n hpa-demo --watch
```

**What happens:**
- Pods 1-9: Schedule successfully (9 × 200m = 1800m)
- Pod 10: **Fails** with `exceeded quota: cpu-quota` error
- HPA shows desired=10 but current=9

**Verify the error:**
```bash
kubectl get events -n hpa-demo --sort-by='.lastTimestamp' | grep quota
kubectl describe quota cpu-quota -n hpa-demo
```

---

### **Approach 2: High CPU Requests**

Increase per-pod CPU so 10 pods exceed node capacity.

**First, check node capacity:**
```bash
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Then adjust deployment:**
Edit `02-deploy-app.yaml` and change `requests.cpu` to consume more (e.g., 800m).

**Result:**
- Works only if your node has limited CPU
- Error: `Insufficient cpu`
- Less predictable than ResourceQuota

---

## Cleanup

Remove quota to return to normal:
```bash
kubectl delete resourcequota cpu-quota -n hpa-demo
```

## Native K8s Concepts

**ResourceQuota:**
```
ResourceQuota (namespace-level)
  ↓ enforces limits on
Total CPU/memory requests across all pods
  ↓ blocks
Pod scheduling when quota exceeded
  ↓ inspect
kubectl describe quota -n <namespace>
```

**Pod Scheduling Failure:**
```
HPA increases Deployment replicas
  ↓ creates
ReplicaSet tries to create Pod
  ↓ blocked by
ResourceQuota or node capacity
  ↓ shows as
Pod in Pending state with FailedScheduling event
  ↓ inspect
kubectl describe pod <name>, kubectl get events
```
