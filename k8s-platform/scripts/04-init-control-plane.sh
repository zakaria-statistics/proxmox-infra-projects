#!/bin/bash
###############################################################################
# Script: 04-init-control-plane.sh
# Purpose: Initialize Kubernetes control plane
# Run Location: ONLY on VM 201 (k8s-control)
# Timeline: 10-15 minutes
###############################################################################

set -e  # Exit on any error

echo "======================================"
echo "Control Plane Initialization"
echo "======================================"
echo

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Configuration
CONTROL_PLANE_IP=$(hostname -I | awk '{print $1}')
POD_NETWORK_CIDR="10.244.0.0/16"

echo "Configuration:"
echo "  Control Plane IP: $CONTROL_PLANE_IP"
echo "  Pod Network CIDR: $POD_NETWORK_CIDR"
echo

# Verify this is the control plane
read -p "Is this the control plane node (k8s-control)? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "This script should only run on the control plane!"
    exit 1
fi

# ============================================================================
echo -e "${BLUE}Step 1: Initialize Kubernetes Control Plane${NC}"
echo
echo "What kubeadm init does:"
echo "  1. Preflight checks: Validates system requirements"
echo "  2. Generates certificates: Creates PKI for secure communication"
echo "     - CA certificate (root of trust)"
echo "     - API server certificate"
echo "     - Service account keys"
echo "  3. Creates kubeconfig files: Authentication configs for components"
echo "  4. Starts control plane components:"
echo "     - kube-apiserver: REST API for all cluster operations"
echo "     - kube-scheduler: Decides which node runs which pod"
echo "     - kube-controller-manager: Runs control loops (deployments, services, etc)"
echo "     - etcd: Distributed key-value store (cluster state database)"
echo "  5. Marks this node as control plane (taint prevents regular pods)"
echo
echo "Command flags explained:"
echo "  --pod-network-cidr=10.244.0.0/16"
echo "    → IP range for pods (NOT your physical network)"
echo "    → 10.244.0.0/16 gives 65,536 IP addresses for pods"
echo "    → Required by Calico/Flannel CNI plugins"
echo
echo "  --apiserver-advertise-address=$CONTROL_PLANE_IP"
echo "    → IP where other nodes will contact the API server"
echo "    → Must be reachable by worker nodes"
echo

echo -e "${YELLOW}Starting initialization... this may take 5-10 minutes${NC}"
echo

# Initialize cluster
kubeadm init \
    --pod-network-cidr=$POD_NETWORK_CIDR \
    --apiserver-advertise-address=$CONTROL_PLANE_IP

echo
echo "✓ Control plane initialized successfully"
echo

# ============================================================================
echo -e "${BLUE}Step 2: Configure kubectl for Current User${NC}"
echo
echo "Why: kubectl needs to know how to authenticate with the API server"
echo "  - admin.conf contains cluster CA cert, API server URL, and admin credentials"
echo "  - Copying to ~/.kube/config makes it the default for kubectl commands"
echo

# Create .kube directory
mkdir -p $HOME/.kube

# Copy admin config
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

# Set proper ownership
chown $(id -u):$(id -g) $HOME/.kube/config

echo "✓ kubectl configured for user: $(whoami)"
echo

# ============================================================================
echo -e "${BLUE}Step 3: Verify Control Plane Components${NC}"
echo

# Wait for components to be ready
echo "Waiting for control plane components to start..."
sleep 10

# Check component status
echo "Control Plane Pods:"
kubectl get pods -n kube-system

echo
echo "Node Status:"
kubectl get nodes

echo

# ============================================================================
echo "======================================"
echo "Control Plane Initialization Complete!"
echo "======================================"
echo

echo -e "${GREEN}Cluster Information:${NC}"
kubectl cluster-info

echo
echo -e "${YELLOW}Important: Save the Join Command!${NC}"
echo
echo "Run this on the control plane to get the worker join command:"
echo -e "${GREEN}kubeadm token create --print-join-command${NC}"
echo
echo "Or run the helper script:"
echo -e "${GREEN}./05-get-join-command.sh${NC}"
echo

echo "Next Steps:"
echo "1. Install CNI plugin (network): ./06a-install-calico.sh"
echo "2. Get join command: ./05-get-join-command.sh"
echo "3. Run join command on worker nodes (202, 203)"
echo

# Display current state
echo "Current Cluster State:"
echo "  Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "  Status: $(kubectl get nodes --no-headers | awk '{print $2}')"
echo
echo -e "${YELLOW}Note: Node will show 'NotReady' until CNI is installed${NC}"
echo
