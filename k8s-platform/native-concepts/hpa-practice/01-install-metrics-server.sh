#!/bin/bash
###############################################################################
# Install Metrics Server
# Purpose: Provides CPU/memory metrics for HPA and kubectl top commands
###############################################################################

set -e

echo "======================================"
echo "Installing Metrics Server"
echo "======================================"
echo

echo "What Metrics Server does:"
echo "  - Collects CPU/memory metrics from kubelet on each node"
echo "  - Exposes metrics via Kubernetes API (/apis/metrics.k8s.io/v1beta1)"
echo "  - Required for: HPA, kubectl top, vertical pod autoscaler"
echo

echo "Native resources created:"
echo "  - Deployment: metrics-server (in kube-system namespace)"
echo "  - Service: metrics-server (ClusterIP)"
echo "  - ServiceAccount: metrics-server"
echo "  - ClusterRole + ClusterRoleBinding (RBAC permissions)"
echo "  - APIService: v1beta1.metrics.k8s.io (extends K8s API)"
echo

# Install Metrics Server
echo "Step 1: Installing Metrics Server manifest..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo
echo "Step 2: Patching for kubeadm clusters (insecure TLS)..."
echo "  Why: kubeadm kubelet certificates are self-signed"
echo "  Flag: --kubelet-insecure-tls (skip TLS verification)"
echo

kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

echo
echo "Step 3: Waiting for Metrics Server to be ready..."
kubectl rollout status deployment metrics-server -n kube-system

echo
echo "======================================"
echo "Metrics Server Installed!"
echo "======================================"
echo

echo "Verify installation:"
echo "  kubectl get deployment metrics-server -n kube-system"
echo "  kubectl get apiservice v1beta1.metrics.k8s.io"
echo

echo "Test metrics collection:"
echo "  kubectl top nodes       # Show node CPU/memory usage"
echo "  kubectl top pods -A     # Show pod CPU/memory usage"
echo

echo "Expected output (wait 15-30 seconds for first metrics):"
echo "  NAME             CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%"
echo "  k8s-control      150m         7%     1200Mi          40%"
echo "  k8s-worker-01    100m         5%     800Mi           27%"
echo

echo "Next step: Deploy test application"
echo "  kubectl apply -f 02-deploy-app.yaml"
echo
