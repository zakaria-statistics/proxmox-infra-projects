#!/bin/bash
###############################################################################
# Cleanup HPA Demo
# Purpose: Remove all resources created during HPA practice
###############################################################################

echo "======================================"
echo "Cleaning up HPA Demo"
echo "======================================"
echo

echo "This will delete:"
echo "  - Namespace: hpa-demo (and everything in it)"
echo "  - HPA: php-apache-hpa"
echo "  - Deployment: php-apache"
echo "  - Service: php-apache"
echo "  - Pods: All php-apache pods"
echo
echo "Metrics Server will remain (used by other features)"
echo

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo "Deleting namespace hpa-demo..."
kubectl delete namespace hpa-demo

echo
echo "✓ Cleanup complete!"
echo

echo "Verify deletion:"
echo "  kubectl get namespace hpa-demo  # Should show 'not found'"
echo "  kubectl get all -n hpa-demo     # Should show 'No resources found'"
echo

echo "Metrics Server status (should still be running):"
kubectl get deployment metrics-server -n kube-system

echo
echo "To redo the HPA practice:"
echo "  1. kubectl apply -f 02-deploy-app.yaml"
echo "  2. kubectl apply -f 03-create-hpa.yaml"
echo "  3. ./04-generate-load.sh"
echo
