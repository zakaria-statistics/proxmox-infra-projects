#!/bin/bash
###############################################################################
# Observe HPA Behavior
# Purpose: Watch autoscaling in action
###############################################################################

echo "======================================"
echo "HPA Observation Commands"
echo "======================================"
echo

echo "Terminal 1: Watch HPA status (run this first)"
echo "  kubectl get hpa -n hpa-demo --watch"
echo
echo "  Output columns:"
echo "    NAME            REFERENCE          TARGETS   MINPODS   MAXPODS   REPLICAS   AGE"
echo "    php-apache-hpa  Deployment/php...  15%/50%   1         10        1          5m"
echo "                                       ↑"
echo "                                       current/target"
echo

echo "Terminal 2: Watch pods being created/deleted"
echo "  kubectl get pods -n hpa-demo --watch"
echo

echo "Terminal 3: Watch resource usage"
echo "  watch 'kubectl top pods -n hpa-demo'"
echo

echo "Terminal 4: Detailed HPA events"
echo "  kubectl describe hpa php-apache-hpa -n hpa-demo"
echo
echo "  Look for events like:"
echo "    'New size: 3; reason: cpu resource utilization (percentage of request) above target'"
echo "    'New size: 1; reason: All metrics below target'"
echo

echo "======================================"
echo "What to Observe:"
echo "======================================"
echo

echo "1. Initial state (before load):"
echo "   - TARGETS: 0%/50% or low %"
echo "   - REPLICAS: 1"
echo

echo "2. During load (after running 04-generate-load.sh):"
echo "   - TARGETS increases: 15% → 50% → 100% → 250%"
echo "   - HPA calculates: desiredReplicas = ceil[1 * (250/50)] = 5"
echo "   - REPLICAS: 1 → 2 → 3 → 5 (gradual scaling)"
echo "   - New pods appear in 'kubectl get pods' (ContainerCreating → Running)"
echo

echo "3. After stopping load:"
echo "   - TARGETS decreases: 250% → 100% → 50% → 5%"
echo "   - HPA waits 5 minutes (stabilizationWindowSeconds)"
echo "   - REPLICAS: 5 → 3 → 1 (gradual scale down)"
echo "   - Pods terminate (Running → Terminating → deleted)"
echo

echo "======================================"
echo "Understanding the Metrics:"
echo "======================================"
echo

echo "CPU Request vs Usage:"
echo "  - Request: 200m (what we asked for in 02-deploy-app.yaml)"
echo "  - Usage: Actual CPU used by pod (from Metrics Server)"
echo "  - Utilization: (Usage / Request) * 100%"
echo
echo "Example:"
echo "  Pod using 100m CPU, request is 200m → 50% utilization (at target)"
echo "  Pod using 400m CPU, request is 200m → 200% utilization (scale up!)"
echo

echo "======================================"
echo "HPA Decision Log (describe hpa):"
echo "======================================"
echo

echo "You'll see events like this:"
echo
echo "  Conditions:"
echo "    Type            Status  Reason              Message"
echo "    ----            ------  ------              -------"
echo "    AbleToScale     True    ReadyForNewScale    recommended 3 replicas"
echo "    ScalingActive   True    ValidMetricFound    HPA able to fetch metrics"
echo "    ScalingLimited  False   DesiredWithinRange  desired count within range"
echo
echo "  Events:"
echo "    Type    Reason             Age   Message"
echo "    ----    ------             ----  -------"
echo "    Normal  SuccessfulRescale  2m    New size: 3; reason: cpu above target"
echo "    Normal  SuccessfulRescale  5m    New size: 1; reason: All metrics below target"
echo

echo "======================================"
echo "Quick Commands:"
echo "======================================"
echo

cat <<'EOF'
# All-in-one dashboard view:
watch 'echo "=== HPA ===" && kubectl get hpa -n hpa-demo && echo && echo "=== Pods ===" && kubectl get pods -n hpa-demo && echo && echo "=== Resources ===" && kubectl top pods -n hpa-demo'

# Just HPA watch:
kubectl get hpa -n hpa-demo --watch

# See scaling events:
kubectl describe hpa php-apache-hpa -n hpa-demo | tail -20

# Check current replica count:
kubectl get deployment php-apache -n hpa-demo

EOF

echo
echo "Run any of the above commands to observe HPA in action!"
echo
