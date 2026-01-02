# Kubernetes Resource Optimization Guide

## Table of Contents

1. [Understanding Resource Requests vs Limits](#understanding-resource-requests-vs-limits)
2. [Right-Sizing Methodology](#right-sizing-methodology)
3. [Vertical Pod Autoscaler (VPA)](#vertical-pod-autoscaler-vpa)
4. [Monitoring with Prometheus](#monitoring-with-prometheus)
5. [Cluster Capacity Planning](#cluster-capacity-planning)
6. [Production Best Practices](#production-best-practices)

---

## Understanding Resource Requests vs Limits

### Native K8s Resource Model

```yaml
resources:
  requests:    # What scheduler uses for placement
    cpu: 150m
    memory: 64Mi
  limits:      # What kubelet enforces at runtime
    cpu: 500m
    memory: 128Mi
```

### How They Affect Scheduling and Runtime

```
┌─────────────────────────────────────────────────────────┐
│ Deployment creates Pod                                  │
└─────────────────┬───────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────┐
│ Scheduler (uses REQUESTS)                               │
│ - Checks: node.allocatable - sum(requests)             │
│ - Decides: Can this pod fit?                           │
│ - Guarantees: Pod gets at least this much              │
└─────────────────┬───────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────┐
│ Kubelet (enforces LIMITS)                               │
│ - CPU: Throttles if exceeds limit                      │
│ - Memory: OOMKills if exceeds limit                    │
│ - Allows bursting: Can use more than request if free   │
└─────────────────────────────────────────────────────────┘
```

### QoS Classes (Native K8s)

Kubernetes assigns Quality of Service based on requests/limits:

| QoS Class | Criteria | Behavior |
|-----------|----------|----------|
| **Guaranteed** | requests == limits | Last to be evicted |
| **Burstable** | requests < limits | Evicted before Guaranteed |
| **BestEffort** | No requests/limits | First to be evicted |

```bash
# Check QoS class
kubectl get pod <pod-name> -n hpa-demo -o jsonpath='{.status.qosClass}'
```

---

## Right-Sizing Methodology

### The Problem: Over-Provisioning

**Your scenario:**
```
Requested: 200m CPU per pod
Actual:    130m CPU per pod (65% utilization)
Waste:     70m per pod × 25 pods = 1750m wasted!
```

**Impact:**
- Scheduler blocks new pods (thinks nodes are full)
- Cluster looks 95% allocated but only 57% utilized
- Wasted money (cloud costs based on allocated, not used)

### Right-Sizing Process

#### Step 1: Gather Current Usage Data

```bash
# Live metrics (last ~60 seconds)
kubectl top pods -n hpa-demo

# Average across all pods
kubectl top pods -n hpa-demo --no-headers | \
  awk '{sum+=$2; count++} END {print "Avg CPU:", sum/count "m"}'
```

#### Step 2: Calculate P95 Usage (Production Method)

For production, you need historical data:

```bash
# Using Prometheus (if available)
# Query P95 CPU over last 7 days:
rate(container_cpu_usage_seconds_total{pod=~"php-apache.*"}[5m])

# Using kubectl with sampling (poor man's method)
for i in {1..100}; do
  kubectl top pod -n hpa-demo --no-headers | awk '{print $2}'
  sleep 10
done | sort -n | awk 'BEGIN{c=0} {val[c++]=$1} END{print "P95:", val[int(c*0.95)]}'
```

#### Step 3: Set Request = P95 + Safety Margin

```
Recommendation:
  request = P95_usage × 1.2  (20% safety margin)
  limit = request × 2-4      (burst capacity)

Your case:
  P95: ~140m (estimated from avg 130m)
  Request: 140m × 1.2 = 168m → round to 150m ✓
  Limit: 150m × 3 = 450m → use 500m ✓
```

#### Step 4: Apply and Monitor

```bash
# Apply new requests
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

# Monitor for OOMKills or CPU throttling
kubectl get events -n hpa-demo --watch
kubectl top pods -n hpa-demo
```

#### Step 5: Iterate

Re-evaluate every 2-4 weeks or after traffic pattern changes.

---

## Vertical Pod Autoscaler (VPA)

### What is VPA?

**Native K8s resource:** Auto-adjusts pod requests/limits based on usage

```
VPA Controller
    ↓ (monitors actual usage)
Recommender
    ↓ (calculates optimal requests)
Updater
    ↓ (applies recommendations)
Pod (restarted with new resources)
```

### VPA vs HPA

| Feature | HPA | VPA |
|---------|-----|-----|
| Scales | Pod count (horizontal) | Pod resources (vertical) |
| Trigger | Metrics (CPU/mem) | Historical usage |
| Requires restart? | No | Yes (in most modes) |
| Use case | Traffic spikes | Right-sizing |

### Installing VPA

```bash
# Clone VPA repo
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler

# Install VPA CRDs and controllers
./hack/vpa-up.sh

# Verify
kubectl get pods -n kube-system | grep vpa
```

### VPA Modes

#### 1. Recommendation Mode (Safe)

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: php-apache-vpa
  namespace: hpa-demo
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  updatePolicy:
    updateMode: "Off"  # Only recommend, don't apply
```

```bash
# Apply VPA
kubectl apply -f vpa-recommend.yaml

# Get recommendations (after ~5 minutes)
kubectl describe vpa php-apache-vpa -n hpa-demo
```

**Output:**
```
Recommendation:
  Container Recommendations:
    Container Name: php-apache
    Lower Bound:     cpu: 100m, memory: 50Mi
    Target:          cpu: 150m, memory: 64Mi  ← Use this!
    Uncapped Target: cpu: 150m, memory: 64Mi
    Upper Bound:     cpu: 200m, memory: 128Mi
```

#### 2. Auto Mode (Aggressive)

```yaml
updatePolicy:
  updateMode: "Auto"  # Automatically applies recommendations
```

**Warning:** Restarts pods! Use with PodDisruptionBudgets.

#### 3. Initial Mode (New Deployments)

```yaml
updatePolicy:
  updateMode: "Initial"  # Only sets resources on pod creation
```

### VPA with HPA (Compatibility)

**Problem:** VPA and HPA can conflict on CPU/memory metrics

**Solution:** Use different metrics
```yaml
# HPA: Scale on CPU
# VPA: Only adjust memory
spec:
  resourcePolicy:
    containerPolicies:
    - containerName: php-apache
      mode: "Off"
      controlledResources: ["memory"]  # VPA manages memory only
```

---

## Monitoring with Prometheus

### Why Prometheus?

- **Historical data:** kubectl top only shows last ~60s
- **P95/P99 metrics:** Better than averages for right-sizing
- **Alerting:** Know when pods are CPU throttled or OOMKilled
- **Dashboards:** Grafana visualization

### Installing Prometheus (Helm)

```bash
# Add Prometheus repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace

# Verify
kubectl get pods -n monitoring
```

### Key Metrics for Right-Sizing

#### CPU Metrics

```promql
# Current CPU usage (cores)
rate(container_cpu_usage_seconds_total{namespace="hpa-demo"}[5m])

# CPU usage as % of request
rate(container_cpu_usage_seconds_total{namespace="hpa-demo"}[5m])
  /
on(pod) kube_pod_container_resource_requests{resource="cpu"}

# P95 CPU over 7 days
quantile_over_time(0.95,
  rate(container_cpu_usage_seconds_total{namespace="hpa-demo"}[5m])[7d:1h]
)
```

#### Memory Metrics

```promql
# Current memory usage
container_memory_working_set_bytes{namespace="hpa-demo"}

# Memory as % of request
container_memory_working_set_bytes{namespace="hpa-demo"}
  /
on(pod) kube_pod_container_resource_requests{resource="memory"}

# P95 memory over 7 days
quantile_over_time(0.95,
  container_memory_working_set_bytes{namespace="hpa-demo"}[7d:1h]
)
```

#### CPU Throttling (Indicates limits too low)

```promql
# Throttled CPU time
rate(container_cpu_cfs_throttled_seconds_total{namespace="hpa-demo"}[5m])

# Throttling %
rate(container_cpu_cfs_throttled_seconds_total[5m])
  /
rate(container_cpu_cfs_periods_total[5m]) * 100
```

### Grafana Dashboard

Import dashboard ID: **3119** (Kubernetes Cluster Monitoring)

Or create custom queries:
```bash
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000
# Login: admin / prom-operator
```

### Alerting on Resource Issues

```yaml
# PrometheusRule for CPU throttling
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: resource-alerts
  namespace: monitoring
spec:
  groups:
  - name: resources
    interval: 30s
    rules:
    - alert: HighCPUThrottling
      expr: |
        rate(container_cpu_cfs_throttled_seconds_total[5m])
        / rate(container_cpu_cfs_periods_total[5m]) > 0.25
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.pod }} CPU throttled >25%"
        description: "Consider increasing CPU limits"
```

---

## Cluster Capacity Planning

### Node Capacity Formula

```
Node Allocatable CPU
  = Total CPU - System Reserved - Eviction Threshold

Your nodes:
  Total: 3000m (3 cores)
  System reserved: ~450m (kube-system pods)
  Eviction: ~50m (kubelet buffer)
  Allocatable: ~2500m per node
```

### Bin-Packing Efficiency

```bash
# Check current allocation vs usage
kubectl describe nodes | grep -A 5 "Allocated resources"

# Efficiency calculation
Efficiency = (Actual Usage) / (Requested) × 100%

Your cluster:
  Requested: 5000m (before optimization)
  Actual: 3250m
  Efficiency: 65% ❌

After optimization (150m requests):
  Requested: 5100m
  Actual: 3250m
  Efficiency: 64% (similar, but more pods fit!)
```

### Headroom Planning

**Rule:** Keep 20-30% free for:
- Rolling updates (surge capacity)
- Traffic spikes
- Node failures

```
Target allocation: 70-80% of node capacity

Your nodes:
  Capacity: 2500m per node
  Target max: 2000m (80%)
  Current: 2550m (over target! ⚠️)
```

### Cluster Autoscaler (Cloud)

**Native K8s tool:** Auto-adds/removes nodes based on pending pods

```yaml
# AWS example (for reference)
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler
  namespace: kube-system
data:
  min-nodes: "2"
  max-nodes: "10"
```

**How it works:**
```
Pending Pods (scheduler can't place)
    ↓
Cluster Autoscaler detects
    ↓
Adds node to cluster
    ↓
Pods schedule on new node
```

---

## Production Best Practices

### 1. Resource Request Guidelines

```yaml
# Microservices
requests:
  cpu: 100-500m
  memory: 128-512Mi

# Web frontends
requests:
  cpu: 200-1000m
  memory: 256Mi-1Gi

# Databases (avoid HPA, use vertical scaling)
requests:
  cpu: 2000m-4000m
  memory: 4-16Gi
```

### 2. Limit Guidelines

```yaml
# CPU: 2-4x request (allow bursting)
limits:
  cpu: 500m  # request was 150m

# Memory: 1.5-2x request (prevent OOMKills)
limits:
  memory: 128Mi  # request was 64Mi
```

### 3. PodDisruptionBudget (For Rolling Updates)

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: php-apache-pdb
  namespace: hpa-demo
spec:
  minAvailable: 80%  # Keep 80% available during updates
  selector:
    matchLabels:
      app: php-apache
```

### 4. ResourceQuotas (Namespace Limits)

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: hpa-demo-quota
  namespace: hpa-demo
spec:
  hard:
    requests.cpu: "10"       # Max 10 cores requested
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    pods: "50"               # Max 50 pods
```

### 5. LimitRanges (Default Resources)

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: hpa-demo
spec:
  limits:
  - default:        # Default limits
      cpu: 500m
      memory: 128Mi
    defaultRequest: # Default requests
      cpu: 150m
      memory: 64Mi
    type: Container
```

### 6. Monitoring Checklist

- [ ] CPU usage vs requests (target: 60-80%)
- [ ] Memory usage vs requests (target: 60-80%)
- [ ] CPU throttling (target: <10%)
- [ ] OOMKills (target: 0)
- [ ] Pending pods (target: 0)
- [ ] Node allocatable vs capacity (target: 70-80%)

### 7. Right-Sizing Workflow

```
Week 1: Deploy with conservative requests (2x expected)
    ↓
Week 2-4: Monitor actual usage (Prometheus/VPA)
    ↓
Month 1: Adjust to P95 + 20% margin
    ↓
Month 2-3: Monitor for issues (OOM, throttling)
    ↓
Quarter: Re-evaluate and adjust
```

---

## Tools Summary

| Tool | Purpose | Installation |
|------|---------|--------------|
| **kubectl top** | Live metrics (60s) | Built-in (requires metrics-server) |
| **Metrics Server** | Resource metrics API | `kubectl apply -f metrics-server.yaml` |
| **VPA** | Auto-rightsizing | `./vpa-up.sh` |
| **Prometheus** | Historical metrics | `helm install prometheus ...` |
| **Grafana** | Visualization | Included with kube-prometheus-stack |
| **Goldilocks** | VPA recommendations | `helm install goldilocks ...` |
| **Cluster Autoscaler** | Node autoscaling | Cloud-specific |

---

## Example: Full Right-Sizing Workflow

```bash
# 1. Deploy app with conservative resources
kubectl apply -f deployment.yaml  # 200m CPU request

# 2. Generate realistic load
kubectl apply -f load-generator.yaml

# 3. Install VPA in recommendation mode
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: php-apache-vpa
  namespace: hpa-demo
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  updatePolicy:
    updateMode: "Off"
EOF

# 4. Wait 5-10 minutes, check recommendations
kubectl describe vpa php-apache-vpa -n hpa-demo

# 5. Apply VPA recommendation
kubectl patch deployment php-apache -n hpa-demo --patch "
spec:
  template:
    spec:
      containers:
      - name: php-apache
        resources:
          requests:
            cpu: 150m  # From VPA target
          limits:
            cpu: 500m
"

# 6. Monitor for issues
kubectl top pods -n hpa-demo
kubectl get events -n hpa-demo | grep -i oom

# 7. Iterate as needed
```

---

## References

- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [VPA GitHub](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [Resource Bin Packing](https://kubernetes.io/docs/concepts/scheduling-eviction/resource-bin-packing/)
