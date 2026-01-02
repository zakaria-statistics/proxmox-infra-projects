# HPA Practice Scenarios - Structured Learning Path

## Overview

This guide provides **precise, step-by-step scenarios** to practice HPA concepts systematically.

Each scenario includes:
- ✅ Clear objectives
- 📋 Step-by-step commands
- 🔍 What to observe
- ✓ Verification checkpoints
- 💡 Learning outcomes

---

## Prerequisites Check

```bash
# Verify cluster is ready
kubectl get nodes
# Expected: 3 nodes (1 control-plane, 2 workers) all Ready

# Verify metrics-server is running
kubectl get pods -n kube-system -l k8s-app=metrics-server
# Expected: 1 pod Running

# Test metrics API
kubectl top nodes
# Expected: CPU and memory usage for all nodes

# Create namespace
kubectl create namespace hpa-demo --dry-run=client -o yaml | kubectl apply -f -
```

---

## Scenario 1: Basic HPA Scaling (30 minutes)

### Objective
Understand how HPA scales pods based on CPU metrics.

### Setup

```bash
cd /root/claude/k8s-platform/native-concepts/hpa-practice

# 1. Deploy application
kubectl apply -f 02-deploy-app.yaml

# 2. Verify deployment
kubectl get deployment,svc -n hpa-demo
```

**✓ Checkpoint 1:** 1 pod running, service created

### Create HPA

```bash
# 3. Create HPA resource
kubectl apply -f 03-create-hpa.yaml

# 4. Describe HPA
kubectl describe hpa php-apache-hpa -n hpa-demo
```

**🔍 Observe:**
```
Metrics: ( current / target )
  resource cpu: 0% (1m) / 50%
Min replicas: 1
Max replicas: 10
Deployment pods: 1 current / 1 desired
```

**✓ Checkpoint 2:** HPA created, showing 0% CPU usage

### Generate Load

```bash
# 5. Start load generator (in terminal 1)
./04-generate-load.sh

# 6. Watch HPA scale (in terminal 2)
watch -n 2 'kubectl get hpa,pods -n hpa-demo'
```

**🔍 Observe over 2-3 minutes:**
1. CPU rises above 50% target
2. HPA calculates desired replicas
3. Deployment scales up
4. New pods start
5. CPU distributes across pods

**Expected timeline:**
```
T+0s:   1 pod,  0% CPU
T+30s:  1 pod,  >100% CPU (load generator started)
T+45s:  HPA calculates: need 5 pods
T+60s:  5 pods scaling up
T+90s:  5 pods running, CPU ~50% each
T+120s: HPA may scale to 10 (if still over target)
```

**✓ Checkpoint 3:** Pods scaled to 5-10, CPU ~50-60% per pod

### Stop Load and Observe Scale-Down

```bash
# 7. Stop load generator (Ctrl+C in terminal 1)

# 8. Watch scale-down (terminal 2)
watch -n 2 'kubectl get hpa,pods -n hpa-demo'
```

**🔍 Observe over 5-10 minutes:**
1. CPU drops below 50%
2. HPA waits **5 minutes** (stabilization window)
3. Slowly scales down (50% per minute)
4. Eventually back to 1 pod

**Expected timeline:**
```
T+0s:    10 pods, CPU dropping
T+30s:   10 pods, CPU ~5-10% (load stopped)
T+5m:    HPA calculates: need 1 pod (after stabilization)
T+6m:    Scale down to 5 pods (50% reduction)
T+7m:    Scale down to 3 pods
T+8m:    Scale down to 2 pods
T+9m:    Scale down to 1 pod
```

**✓ Checkpoint 4:** Back to 1 pod after ~10 minutes

### Verification Commands

```bash
# View HPA events
kubectl describe hpa php-apache-hpa -n hpa-demo | grep Events -A 20

# View deployment revisions
kubectl rollout history deployment php-apache -n hpa-demo

# Check pod metrics
kubectl top pods -n hpa-demo
```

### Learning Outcomes

✅ HPA queries metrics every 15 seconds
✅ Scale-up is aggressive (0s stabilization)
✅ Scale-down is conservative (5min stabilization)
✅ Target metric is % of resource request
✅ HPA uses formula: `ceil[currentReplicas × (currentMetric / targetMetric)]`

---

## Scenario 2: Resource Requests Impact (30 minutes)

### Objective
Understand how resource requests affect HPA calculations.

### Setup

```bash
# 1. Reset to 1 pod
kubectl delete hpa php-apache-hpa -n hpa-demo
kubectl scale deployment php-apache --replicas=1 -n hpa-demo
```

### Test with 200m CPU Request

```bash
# 2. Verify current request
kubectl get deployment php-apache -n hpa-demo -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}'
# Should show: 200m

# 3. Recreate HPA
kubectl apply -f 03-create-hpa.yaml

# 4. Generate load
./04-generate-load.sh

# 5. Observe in new terminal
watch -n 2 'kubectl get hpa -n hpa-demo && echo && kubectl top pods -n hpa-demo'
```

**🔍 Observe:**
```
With 200m request:
  - Pods use ~130m actual
  - HPA sees: 130m / 200m = 65% of request
  - Target: 50%
  - Decision: Scale up (65% > 50%)
```

**✓ Checkpoint 1:** Note final pod count (likely 5-10)

### Test with 150m CPU Request

```bash
# 6. Stop load (Ctrl+C)

# 7. Wait for scale down to 1 pod
kubectl get hpa -n hpa-demo -w

# 8. Update CPU request
kubectl patch deployment php-apache -n hpa-demo --patch '
spec:
  template:
    spec:
      containers:
      - name: php-apache
        resources:
          requests:
            cpu: 150m
          limits:
            cpu: 500m
'

# 9. Wait for rollout
kubectl rollout status deployment php-apache -n hpa-demo

# 10. Generate same load
./04-generate-load.sh

# 11. Observe
watch -n 2 'kubectl get hpa -n hpa-demo && echo && kubectl top pods -n hpa-demo'
```

**🔍 Observe:**
```
With 150m request:
  - Pods use ~130m actual (same as before)
  - HPA sees: 130m / 150m = 87% of request
  - Target: 50%
  - Decision: Scale up MORE (87% > 65%)
```

**✓ Checkpoint 2:** More pods than with 200m request!

### Comparison

```bash
# View side-by-side
echo "CPU Request: 200m → Pod count: ~5-10"
echo "CPU Request: 150m → Pod count: ~10-15"
echo "Actual usage: ~130m (unchanged)"
```

### Learning Outcomes

✅ HPA calculates based on **% of request**, not absolute usage
✅ Lower requests → higher % → more pods
✅ Higher requests → lower % → fewer pods
✅ Right-sizing affects both scheduling AND autoscaling

---

## Scenario 3: Cluster Resource Exhaustion (30 minutes)

### Objective
Experience scheduler blocking due to insufficient node resources.

### Setup

```bash
# 1. Reset
kubectl delete hpa php-apache-hpa -n hpa-demo
kubectl scale deployment php-apache --replicas=1 -n hpa-demo
```

### Push Beyond Cluster Capacity

```bash
# 2. Set high max replicas
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache-hpa
  namespace: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 50  # Intentionally higher than capacity
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
EOF

# 3. Generate heavy load
./04-generate-load.sh

# 4. Watch in multiple terminals
# Terminal 1: HPA
watch -n 2 'kubectl get hpa -n hpa-demo'

# Terminal 2: Pods
watch -n 2 'kubectl get pods -n hpa-demo'

# Terminal 3: Nodes
watch -n 2 'kubectl top nodes'
```

**🔍 Observe:**
1. HPA wants many pods (e.g., 34)
2. Only some pods run (e.g., 25)
3. Rest are Pending
4. Nodes show high allocation

**✓ Checkpoint 1:** See pending pods

### Investigate Pending Pods

```bash
# 5. List pending pods
kubectl get pods -n hpa-demo --field-selector=status.phase=Pending

# 6. Describe one pending pod
PENDING_POD=$(kubectl get pods -n hpa-demo --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $PENDING_POD -n hpa-demo
```

**🔍 Look for:**
```
Events:
  Warning  FailedScheduling  ...  0/3 nodes are available:
    1 node(s) had untolerated taint,
    2 Insufficient cpu
```

**✓ Checkpoint 2:** Understand "Insufficient cpu" message

### Analyze Node Capacity

```bash
# 7. Check node allocations
kubectl describe nodes | grep -A 5 "Allocated resources"

# 8. Calculate capacity
kubectl describe node k8s-worker-01 | grep -E "Allocatable:|Allocated"
```

**🔍 Calculate:**
```
Node capacity: 3000m
System pods: ~450m
Available: ~2550m

Pod request: 150m
Max pods: 2550m / 150m = 17 per node
Total capacity: 17 × 2 workers = 34 pods

HPA wants: 50 pods
Result: 34 running, 16 pending ✓
```

**✓ Checkpoint 3:** Math matches reality!

### Check HPA Conditions

```bash
# 9. View HPA status
kubectl get hpa php-apache-hpa -n hpa-demo -o jsonpath='{.status.conditions}' | jq
```

**🔍 Look for:**
```json
{
  "type": "ScalingLimited",
  "status": "True",
  "reason": "TooManyReplicas"
}
```

**✓ Checkpoint 4:** HPA knows it's limited!

### Learning Outcomes

✅ Scheduler respects resource requests (hard limits)
✅ Pending pods wait indefinitely for resources
✅ HPA condition "ScalingLimited" indicates capacity reached
✅ Node capacity = allocatable - system pods
✅ Need cluster autoscaler or more nodes for unlimited scaling

---

## Scenario 4: Rolling Update with Resource Constraints (30 minutes)

### Objective
Understand rolling update behavior when cluster is near capacity.

### Setup

```bash
# 1. Fill cluster to ~80% capacity
kubectl delete hpa php-apache-hpa -n hpa-demo
kubectl scale deployment php-apache --replicas=25 -n hpa-demo

# 2. Wait for all pods running
kubectl wait --for=condition=ready pod -l app=php-apache -n hpa-demo --timeout=120s

# 3. Check node utilization
kubectl top nodes
```

**✓ Checkpoint 1:** 25 pods running, nodes ~80% utilized

### Trigger Rolling Update

```bash
# 4. Change CPU request (triggers rolling update)
kubectl patch deployment php-apache -n hpa-demo --patch '
spec:
  template:
    spec:
      containers:
      - name: php-apache
        resources:
          requests:
            cpu: 100m  # Down from 150m
          limits:
            cpu: 500m
'

# 5. Watch rollout
watch -n 2 'kubectl get deployment,rs,pods -n hpa-demo'
```

**🔍 Observe:**
1. New ReplicaSet created
2. Old pods remain (25)
3. New pods start (gradual)
4. Old pods terminate (gradual)
5. Both ReplicaSets active during update

**Expected behavior:**
```
maxSurge: 25% → Can have 31 pods during update (25 × 1.25)
maxUnavailable: 25% → Must keep 19 pods (25 × 0.75)

Timeline:
  T+0s:  Old RS: 25, New RS: 0
  T+10s: Old RS: 25, New RS: 6 (surge)
  T+20s: Old RS: 19, New RS: 6 (drain old)
  T+30s: Old RS: 19, New RS: 12
  ...
  T+90s: Old RS: 0, New RS: 25 ✓
```

**✓ Checkpoint 2:** Update completes successfully

### Try Update at 95% Capacity

```bash
# 6. Scale to near-max
kubectl scale deployment php-apache --replicas=30 -n hpa-demo

# 7. Verify all running
kubectl get pods -n hpa-demo --field-selector=status.phase=Running | wc -l

# 8. Try another update
kubectl patch deployment php-apache -n hpa-demo --patch '
spec:
  template:
    metadata:
      labels:
        version: v2  # Cosmetic change to trigger update
'

# 9. Watch for issues
kubectl rollout status deployment php-apache -n hpa-demo --timeout=120s
```

**🔍 Observe:**
- Update may stall
- Some new pods Pending
- Old pods can't drain
- "ProgressDeadlineExceeded" after 10 minutes

**✓ Checkpoint 3:** Understand rolling update capacity requirements

### Fix Stuck Rollout

```bash
# 10. Scale down to make room
kubectl scale deployment php-apache --replicas=20 -n hpa-demo

# 11. Wait for rollout to complete
kubectl rollout status deployment php-apache -n hpa-demo

# 12. Scale back up
kubectl scale deployment php-apache --replicas=30 -n hpa-demo
```

**✓ Checkpoint 4:** Update completes after scaling down

### Learning Outcomes

✅ Rolling updates need surge capacity (maxSurge)
✅ Near-capacity clusters can block updates
✅ ProgressDeadlineExceeded = rollout stuck for 10min
✅ Always plan 20-30% headroom for updates
✅ Alternative: use `strategy: Recreate` (accepts downtime)

---

## Scenario 5: HPA Scale-Up/Down Behavior (20 minutes)

### Objective
Understand HPA scaling policies and stabilization windows.

### Setup

```bash
# 1. Reset
kubectl delete hpa php-apache-hpa -n hpa-demo
kubectl scale deployment php-apache --replicas=1 -n hpa-demo
```

### Default Behavior (Fast Up, Slow Down)

```bash
# 2. Create HPA with default behavior
kubectl apply -f 03-create-hpa.yaml

# 3. Start timer and generate load
date && ./04-generate-load.sh

# 4. Watch with timestamps
watch -n 1 'date && kubectl get hpa,pods -n hpa-demo'
```

**🔍 Time the scale-up:**
```
T+0s:   1 pod
T+15s:  HPA detects high CPU
T+30s:  Scaled to 5 pods
T+45s:  Scaled to 10 pods
```

**⏱️ Scale-up:** ~30-45 seconds to max

```bash
# 5. Stop load and time scale-down
date  # Note time
# Ctrl+C to stop load

# 6. Continue watching
watch -n 1 'date && kubectl get hpa,pods -n hpa-demo'
```

**🔍 Time the scale-down:**
```
T+0s:   10 pods, CPU dropping
T+5m:   Still 10 pods (stabilization window!)
T+6m:   Scaled to 5 pods
T+7m:   Scaled to 3 pods
T+8m:   Scaled to 2 pods
T+9m:   Scaled to 1 pod
```

**⏱️ Scale-down:** ~9-10 minutes to minimum

**✓ Checkpoint 1:** Note asymmetric scaling times

### Custom Scaling Policies

```bash
# 7. Create HPA with custom policies
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache-hpa
  namespace: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 2
        periodSeconds: 15
      selectPolicy: Max  # Use whichever scales faster
    scaleDown:
      stabilizationWindowSeconds: 60  # Faster than default 300s
      policies:
      - type: Pods
        value: 1
        periodSeconds: 30  # 1 pod per 30s
      selectPolicy: Min  # Use whichever is slower
EOF

# 8. Test new behavior
./04-generate-load.sh
watch -n 1 'date && kubectl get hpa,pods -n hpa-demo'
```

**🔍 Observe faster scale-down:**
```
T+0s:  10 pods, stop load
T+1m:  Still 10 pods (stabilization: 60s)
T+2m:  Scaled to 9 pods (1 pod per 30s)
T+2m30s: Scaled to 8 pods
T+3m:  Scaled to 7 pods
...
T+10m: Scaled to 1 pod
```

**✓ Checkpoint 2:** Scale-down faster (10min → ~5min)

### Learning Outcomes

✅ Scale-up: aggressive (0s stabilization, 100% or 4 pods per 15s)
✅ Scale-down: conservative (300s stabilization, 50% per 60s)
✅ Prevents flapping (rapid scale up/down)
✅ Customizable via `behavior` field
✅ `selectPolicy: Max` = fastest, `Min` = slowest

---

## Scenario 6: Metrics Verification (20 minutes)

### Objective
Understand metrics flow: kubelet → metrics-server → HPA.

### Verify Metrics Pipeline

```bash
# 1. Deploy app
kubectl apply -f 02-deploy-app.yaml

# 2. Check kubelet metrics (raw)
NODE_IP=$(kubectl get node k8s-worker-01 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
curl -k https://$NODE_IP:10250/metrics | grep container_cpu_usage_seconds_total

# 3. Check metrics-server API
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods | jq

# 4. Verify HPA can read metrics
kubectl get hpa php-apache-hpa -n hpa-demo -o jsonpath='{.status.currentMetrics}' | jq
```

**✓ Checkpoint 1:** Metrics flowing through all layers

### Simulate Metrics-Server Failure

```bash
# 5. Scale down metrics-server
kubectl scale deployment metrics-server -n kube-system --replicas=0

# 6. Create HPA
kubectl apply -f 03-create-hpa.yaml

# 7. Check HPA status
kubectl describe hpa php-apache-hpa -n hpa-demo
```

**🔍 Observe:**
```
Events:
  Warning  FailedGetResourceMetric  ...  failed to get cpu utilization:
    unable to get metrics for resource cpu:
    no metrics returned from resource metrics API
```

**✓ Checkpoint 2:** HPA fails without metrics

```bash
# 8. Restore metrics-server
kubectl scale deployment metrics-server -n kube-system --replicas=1

# 9. Wait for metrics to return
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=60s

# 10. Verify HPA works again
kubectl get hpa php-apache-hpa -n hpa-demo
```

**✓ Checkpoint 3:** HPA recovers automatically

### Learning Outcomes

✅ Metrics flow: kubelet → metrics-server → HPA
✅ HPA queries metrics API every 15 seconds
✅ Metrics-server failure breaks HPA
✅ HPA recovers automatically when metrics return
✅ `kubectl top` also requires metrics-server

---

## Progress Checklist

Track your learning progress:

- [ ] **Scenario 1:** Basic HPA scaling (30min)
  - [ ] Created HPA resource
  - [ ] Observed scale-up during load
  - [ ] Observed scale-down after load
  - [ ] Understood stabilization windows

- [ ] **Scenario 2:** Resource requests impact (30min)
  - [ ] Tested with 200m CPU request
  - [ ] Tested with 150m CPU request
  - [ ] Compared scaling behavior
  - [ ] Understood % of request calculation

- [ ] **Scenario 3:** Resource exhaustion (30min)
  - [ ] Pushed cluster beyond capacity
  - [ ] Observed pending pods
  - [ ] Analyzed node capacity
  - [ ] Saw "ScalingLimited" condition

- [ ] **Scenario 4:** Rolling updates (30min)
  - [ ] Performed update at 80% capacity
  - [ ] Performed update at 95% capacity
  - [ ] Experienced stuck rollout
  - [ ] Fixed with temporary scale-down

- [ ] **Scenario 5:** Scaling behavior (20min)
  - [ ] Timed default scale-up/down
  - [ ] Customized scaling policies
  - [ ] Observed faster scale-down
  - [ ] Understood behavior configuration

- [ ] **Scenario 6:** Metrics verification (20min)
  - [ ] Verified metrics pipeline
  - [ ] Simulated metrics-server failure
  - [ ] Observed HPA failure
  - [ ] Verified automatic recovery

---

## Next Steps

After completing all scenarios:

1. **Read:** `RESOURCE-OPTIMIZATION-GUIDE.md`
2. **Try:** VPA for automatic right-sizing
3. **Install:** Prometheus for historical metrics
4. **Advanced:** Custom metrics (e.g., requests/second)
5. **Production:** PodDisruptionBudgets + ResourceQuotas

---

## Cleanup

```bash
# Remove all HPA practice resources
./cleanup.sh

# Or manual cleanup:
kubectl delete namespace hpa-demo
```

---

## Troubleshooting

### HPA not scaling

```bash
# Check HPA can read metrics
kubectl describe hpa <name> -n hpa-demo

# Check metrics-server
kubectl top pods -n hpa-demo

# Check HPA conditions
kubectl get hpa <name> -n hpa-demo -o jsonpath='{.status.conditions}' | jq
```

### Pods pending

```bash
# Describe pending pod
kubectl describe pod <pod-name> -n hpa-demo | grep Events -A 10

# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Rollout stuck

```bash
# Check rollout status
kubectl rollout status deployment <name> -n hpa-demo

# View rollout history
kubectl rollout history deployment <name> -n hpa-demo

# Rollback if needed
kubectl rollout undo deployment <name> -n hpa-demo
```
