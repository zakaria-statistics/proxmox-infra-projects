#!/bin/bash
###############################################################################
# Cleanup TLS Demo
# Purpose: Remove all resources created during TLS practice
###############################################################################

echo "======================================"
echo "Cleaning up TLS Demo"
echo "======================================"
echo

echo "This will delete:"
echo "  - Namespace: tls-demo (and everything in it)"
echo "  - Ingress: secure-app-ingress"
echo "  - Secret: secure-app-tls"
echo "  - Deployment: secure-app"
echo "  - Service: secure-app"
echo "  - Pods: All secure-app pods"
echo "  - Local certificates: ./certs/ directory"
echo
echo "Will NOT delete:"
echo "  - Ingress Controller (nginx-ingress)"
echo "  - /etc/hosts entry (manual removal if needed)"
echo

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo "Deleting namespace tls-demo..."
kubectl delete namespace tls-demo

echo
echo "Removing local certificate files..."
if [ -d "./certs" ]; then
    rm -rf ./certs
    echo "✓ ./certs/ directory removed"
else
    echo "No ./certs/ directory found"
fi

echo
echo "✓ Cleanup complete!"
echo

echo "Verify deletion:"
echo "  kubectl get namespace tls-demo  # Should show 'not found'"
echo "  kubectl get all -n tls-demo     # Should show 'No resources found'"
echo "  ls ./certs                      # Should show 'No such file or directory'"
echo

echo "Remove /etc/hosts entry (optional):"
echo "  sudo sed -i '/secure-app.local/d' /etc/hosts"
echo

echo "Ingress Controller status (should still be running):"
kubectl get svc -n ingress-nginx ingress-nginx-controller

echo
echo "To redo the TLS practice:"
echo "  1. ./01-generate-certificates.sh"
echo "  2. kubectl apply -f 02-create-tls-secret.yaml"
echo "  3. kubectl apply -f 03-deploy-app.yaml"
echo "  4. kubectl apply -f 04-ingress-with-tls.yaml"
echo "  5. ./05-test-https.sh"
echo
