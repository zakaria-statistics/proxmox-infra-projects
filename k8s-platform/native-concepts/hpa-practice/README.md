# HPA (Horizontal Pod Autoscaler) Practice

## Learning Objectives

**Native Kubernetes concept:** Auto-scale pods based on CPU/memory metrics

**What you'll learn:**
- How Metrics Server provides resource metrics
- How HPA watches metrics and makes scaling decisions
- Resource requests/limits and their role in autoscaling
- Observing autoscaling behavior in real-time

**What this replaces in managed tools:**
- OpenFaaS auto-scaler (uses custom metrics + Prometheus)
- Knative autoscaler (uses request count metrics)
- Both abstract away native HPA

---

## Architecture

```
Metrics Server (collects CPU/memory from kubelets)
       ↓ (provides metrics API)
HPA Resource (queries metrics every 15s)
       ↓ (compares current vs target)
Deployment (scales replicas up/down)
       ↓ (creates/deletes)
Pods (running your application)
```

---

## Steps

1. **Install Metrics Server** - `./01-install-metrics-server.sh`
2. **Deploy test app** - `kubectl apply -f 02-deploy-app.yaml`
3. **Create HPA** - `kubectl apply -f 03-create-hpa.yaml`
4. **Generate load** - `./04-generate-load.sh`
5. **Observe behavior** - `./05-observe.sh`

---

## Native Resources Created

| Resource | Purpose |
|----------|---------|
| Deployment | Manages pod replicas |
| Service | Load balances across pods |
| HPA | Autoscaling logic |
| Metrics Server | Provides CPU/memory metrics |

---

## Key Concepts

### Resource Requests vs Limits

```yaml
resources:
  requests:
    cpu: 100m      # HPA uses this for % calculation
    memory: 64Mi   # Guaranteed minimum
  limits:
    cpu: 200m      # Maximum allowed
    memory: 128Mi  # Pod killed if exceeded
```

**HPA calculation:**
- Target: 50% CPU utilization
- Request: 100m (0.1 cores)
- Current: 150m (150% of request)
- Decision: Scale up!

### HPA Scaling Formula

```
desiredReplicas = ceil[currentReplicas * (currentMetric / targetMetric)]

Example:
- currentReplicas: 1
- currentCPU: 200m (200% of 100m request)
- targetCPU: 50% (50m)
- desiredReplicas = ceil[1 * (200 / 50)] = ceil[4] = 4 pods
```

---

## Comparison: Native vs Managed

### Native HPA (what we're practicing):
```bash
# Manual steps:
1. Deploy app with resource requests
2. Create HPA resource
3. HPA watches metrics, scales deployment

# Full control, full visibility
```

### OpenFaaS (managed - abstracts HPA):
```bash
# One command:
faas-cli deploy --image=myfunction

# Behind the scenes (same as native!):
- Creates Deployment with resource requests
- Creates Service
- Creates HPA (or custom autoscaler)
- You don't see these steps
```

**Learning native first means:** When OpenFaaS autoscaling breaks, you know how to debug the underlying HPA!

---

## Additional Learning Resources

### 📚 Comprehensive Guides

- **[PRACTICE-SCENARIOS.md](./PRACTICE-SCENARIOS.md)** - Structured learning path with 6 hands-on scenarios
  - Scenario 1: Basic HPA scaling
  - Scenario 2: Resource requests impact
  - Scenario 3: Cluster resource exhaustion
  - Scenario 4: Rolling updates with constraints
  - Scenario 5: HPA scale-up/down behavior
  - Scenario 6: Metrics verification

- **[RESOURCE-OPTIMIZATION-GUIDE.md](./RESOURCE-OPTIMIZATION-GUIDE.md)** - Production-ready resource optimization
  - Understanding requests vs limits
  - Right-sizing methodology
  - Vertical Pod Autoscaler (VPA)
  - Monitoring with Prometheus
  - Cluster capacity planning
  - Production best practices

- **[CURRENT-ISSUE-FIX.md](./CURRENT-ISSUE-FIX.md)** - Troubleshooting rolling update deadlocks
  - Rolling update resource constraints
  - How to fix stuck rollouts
  - Verification steps

- **[RESOURCE-EXHAUSTION.md](./RESOURCE-EXHAUSTION.md)** - Deep dive into cluster capacity issues

---

## Quick Start Options

### Option A: Quick Practice (Follow basic steps)
```bash
./01-install-metrics-server.sh  # Already done ✓
kubectl apply -f 02-deploy-app.yaml
kubectl apply -f 03-create-hpa.yaml
./04-generate-load.sh
./05-observe.sh  # In another terminal
```

### Option B: Structured Learning (Recommended)
```bash
# Follow the comprehensive practice scenarios
cat PRACTICE-SCENARIOS.md
# Start with Scenario 1
```

### Option C: Production Learning
```bash
# Study resource optimization for real-world use
cat RESOURCE-OPTIMIZATION-GUIDE.md
```

---

**Ready to start? Run:** `./01-install-metrics-server.sh`
