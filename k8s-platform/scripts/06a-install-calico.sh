#!/bin/bash
###############################################################################
# Script: 06a-install-calico.sh
# Purpose: Install Calico CNI for pod networking
# Run Location: Control plane only (VM 201)
# Timeline: 10-15 minutes
###############################################################################

set -e

echo "======================================"
echo "Install Calico CNI"
echo "======================================"
echo

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}What is CNI (Container Network Interface)?${NC}"
echo "  - Provides network connectivity to pods"
echo "  - Assigns IP addresses to each pod"
echo "  - Routes traffic between pods across nodes"
echo "  - Implements network policies (firewall rules)"
echo

echo -e "${BLUE}Why Calico?${NC}"
echo "  ✓ Production-grade: Used by major companies"
echo "  ✓ Network policies: Advanced security rules"
echo "  ✓ Performance: Direct routing without overlay"
echo "  ✓ Scalability: Handles thousands of nodes"
echo

echo -e "${BLUE}What this installation does:${NC}"
echo "  1. Deploys Calico pods to all nodes (DaemonSet)"
echo "  2. Creates virtual network interfaces on each node"
echo "  3. Sets up routing tables for pod communication"
echo "  4. Enables nodes to reach 'Ready' state"
echo

echo -e "${YELLOW}Installing Calico...${NC}"
echo

# Download and apply Calico manifest
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

echo
echo "✓ Calico manifest applied"
echo

# ============================================================================
echo "Waiting for Calico pods to start..."
echo "(This may take 2-3 minutes)"
echo

# Wait for calico pods
kubectl wait --for=condition=ready pod \
    -l k8s-app=calico-node \
    -n kube-system \
    --timeout=300s

echo
echo "✓ Calico pods are running"
echo

# ============================================================================
echo "Verifying network setup..."
echo

# Check calico pods
echo "Calico Pods:"
kubectl get pods -n kube-system -l k8s-app=calico-node

echo
echo "Node Status:"
kubectl get nodes

echo

# ============================================================================
echo "======================================"
echo "Calico Installation Complete!"
echo "======================================"
echo

echo "Network Configuration:"
echo "  Pod Network: 10.244.0.0/16"
echo "  Service Network: 10.96.0.0/12 (default)"
echo

echo "Verify network is working:"
echo "  kubectl run test-pod --image=nginx --restart=Never"
echo "  kubectl get pod test-pod -o wide  # Should show IP from 10.244.x.x"
echo "  kubectl delete pod test-pod"
echo

echo "Next Steps:"
echo "1. Join worker nodes (if not done): ./05-get-join-command.sh"
echo "2. Install MetalLB: ./06b-install-metallb.sh"
echo
