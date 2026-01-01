#!/bin/bash
###############################################################################
# Generate HEAVY Load on php-apache
# Purpose: Aggressively trigger HPA autoscaling to max replicas
###############################################################################

echo "======================================"
echo "HEAVY Load Generator for HPA Demo"
echo "======================================"
echo

echo "What this does:"
echo "  - Deploys a pod with 10 parallel request streams"
echo "  - No delay between requests (maximum CPU pressure)"
echo "  - Each request causes CPU-intensive computation"
echo "  - CPU usage will spike → HPA will scale rapidly to max replicas"
echo
echo

echo "Starting HEAVY load generator..."
kubectl apply -f 04-load-generator.yaml

echo
echo "Load generator started in background."
echo
echo "Monitor with:"
echo "  kubectl get hpa -n hpa-demo --watch"
echo "  kubectl top pods -n hpa-demo"
echo "  kubectl logs -f load-generator -n hpa-demo"
echo
echo "To STOP the load:"
echo "  kubectl delete pod load-generator -n hpa-demo"
echo
echo "After stopping, HPA will scale down after 5 min stabilization window."
echo
