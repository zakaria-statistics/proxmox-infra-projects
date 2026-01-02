# Current Issue: Rolling Update Deadlock

## Problem Summary

**Status:** 26/43 pods ready, 17 pending

**What's happening:**
```
Old ReplicaSet (200m CPU):  25 pods running ✓
New ReplicaSet (150m CPU):   1 pod running ✓
New ReplicaSet (150m CPU):  17 pods PENDING ❌
                           ──────────────────
Total:                      43 pods (26 running)
```

## Root Cause: Rolling Update + Resource Constraints

### Native K8s Rolling Update Flow:

```
Deployment (revision 2 triggered by patch)
    ↓
Creates new ReplicaSet (php-apache-57544c9599) with 150m requests
    ↓
Rolling update strategy:
  - maxSurge: 25% (can have 25% more pods during update)
  - maxUnavailable: 25% (can have 25% fewer pods during update)
    ↓
Tries to scale up new ReplicaSet while scaling down old one
    ↓
PROBLEM: Not enough CPU for both old + new pods simultaneously!
```

### The Math:

```
Cluster capacity:
  - 2 worker nodes × 3000m = 6000m total
  - System pods: ~450m per node = 900m
  - Available: 5100m for workloads

During rolling update:
  - Old pods: 25 × 200m = 5000m (currently running)
  - New pods: 18 × 150m = 2700m (trying to start)
  - Total needed: 7700m
  - Available: 5100m
  - DEFICIT: -2600m ❌

After update completes:
  - New pods: 34 × 150m = 5100m (will fit perfectly!)
```

### Why It's Stuck:

1. **Old pods won't terminate** until new pods are ready
2. **New pods can't start** due to insufficient CPU
3. **Deadlock!** ⚠️

## Solution Options

### Option 1: Temporary HPA Scale Down (Recommended)

```bash
# Step 1: Reduce HPA max to allow rolling update
kubectl patch hpa php-apache-hpa -n hpa-demo --patch '{"spec":{"maxReplicas":20}}'

# Step 2: Watch HPA scale down
kubectl get hpa -n hpa-demo -w
# Wait until: 20/20 pods

# Step 3: Wait for rolling update to complete
kubectl rollout status deployment php-apache -n hpa-demo

# Step 4: Verify all pods use new resources (150m)
kubectl get rs -n hpa-demo
# Old RS should be 0/0, new RS should be 20/20

# Step 5: Scale HPA back up
kubectl patch hpa php-apache-hpa -n hpa-demo --patch '{"spec":{"maxReplicas":34}}'

# Step 6: Watch it scale to capacity
kubectl get hpa -n hpa-demo -w
```

**Why this works:**
- Reduces total pods → frees up CPU
- Allows rolling update to complete
- Then scales back up with efficient 150m requests

---

### Option 2: Force Delete Old ReplicaSet (Aggressive)

```bash
# Delete old pods to make room for new ones
kubectl delete rs php-apache-84cf58d9f9 -n hpa-demo

# Watch new pods schedule
kubectl get pods -n hpa-demo -w
```

**Warning:** Brief service disruption!

---

### Option 3: Wait It Out (Slow)

```bash
# Eventually old pods will timeout and get replaced
# But with ProgressDeadlineExceeded, this may not happen
kubectl rollout status deployment php-apache -n hpa-demo
```

**Not recommended** - deployment shows "ProgressDeadlineExceeded"

---

## Verification Steps

### After fix, verify:

```bash
# 1. Check ReplicaSets
kubectl get rs -n hpa-demo
# Should see:
#   php-apache-57544c9599   34/34   (new, with 150m)
#   php-apache-84cf58d9f9   0/0     (old, scaled down)

# 2. Verify all pods have new resources
kubectl get pod -n hpa-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\n"}{end}' | grep php-apache

# Should all show: 150m

# 3. Check node utilization
kubectl top nodes
# Should see ~85% allocated vs previous 95%

# 4. Verify no pending pods
kubectl get pods -n hpa-demo --field-selector=status.phase=Pending
# Should be empty

# 5. Check HPA status
kubectl get hpa php-apache-hpa -n hpa-demo
# Should show: 34/34 pods, no ScalingLimited condition
```

---

## What This Teaches

### Native K8s Concepts Learned:

✅ **Rolling Updates** aren't instantaneous - need resources for both old + new
✅ **maxSurge/maxUnavailable** control update speed vs resource usage
✅ **Scheduler blocks** if requests exceed capacity (even during updates)
✅ **ProgressDeadlineExceeded** means update stuck for 10 minutes
✅ **ReplicaSets** are the actual pod managers (Deployment → RS → Pods)

### Production Lessons:

1. **Right-size before scaling** - update at low load
2. **Plan for surge capacity** - rolling updates need headroom
3. **Monitor rollout status** - don't assume it completes
4. **Use Recreate strategy** for resource-constrained clusters (accepts downtime)

### Alternative: Recreate Strategy

```yaml
spec:
  strategy:
    type: Recreate  # vs RollingUpdate
```

**Trade-off:**
- No surge capacity needed ✓
- Brief downtime during update ❌

---

## Quick Fix Command

```bash
# One-liner to fix (reduce max, wait, restore):
kubectl patch hpa php-apache-hpa -n hpa-demo --patch '{"spec":{"maxReplicas":20}}' && \
sleep 60 && \
kubectl rollout status deployment php-apache -n hpa-demo && \
kubectl patch hpa php-apache-hpa -n hpa-demo --patch '{"spec":{"maxReplicas":34}}'
```

Run this and watch it resolve! 🚀
