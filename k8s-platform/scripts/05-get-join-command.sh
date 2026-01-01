#!/bin/bash
###############################################################################
# Script: 05-get-join-command.sh
# Purpose: Generate join command for worker nodes
# Run Location: Control plane only (VM 201)
# Timeline: 1 minute
###############################################################################

# kubeadm join 192.168.11.201:6443 --token yaiz1j.hawsz59pjb0223ys \
#        --discovery-token-ca-cert-hash sha256:24a69cc0430f4f2f757305cb7d89ad1119bdd3930fc65157ef8eb5754b4cf46c

echo "======================================"
echo "Generate Worker Join Command"
echo "======================================"
echo

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

echo -e "${BLUE}What this does:${NC}"
echo "  - Generates a new bootstrap token (valid for 24 hours)"
echo "  - Creates complete join command with:"
echo "    * Token: Temporary credential for authentication"
echo "    * CA cert hash: Verifies control plane identity (prevents MITM)"
echo "    * API server endpoint: Where to connect"
echo

echo -e "${YELLOW}Worker Join Command:${NC}"
echo

# Generate and display join command
kubeadm token create --print-join-command

echo
echo "======================================"
echo

echo -e "${GREEN}Instructions:${NC}"
echo "1. Copy the command above"
echo "2. SSH into each worker node (k8s-worker-01, k8s-worker-02)"
echo "3. Run the command as root (with sudo)"
echo
echo "Example:"
echo "  ssh k8sadmin@192.168.11.202"
echo "  sudo <paste join command here>"
echo

echo "Security Note:"
echo "  - Token is valid for 24 hours"
echo "  - CA cert hash ensures you're joining the correct cluster"
echo "  - After join, nodes use certificates for authentication"
echo

echo "After joining workers, verify with:"
echo "  kubectl get nodes"
echo
