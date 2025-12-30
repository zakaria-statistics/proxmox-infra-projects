#!/bin/bash
###############################################################################
# Script: 06b-install-metallb.sh
# Purpose: Install MetalLB load balancer for bare metal
# Run Location: Control plane only (VM 201)
# Timeline: 10 minutes
###############################################################################

set -e

echo "======================================"
echo "Install MetalLB Load Balancer"
echo "======================================"
echo

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
IP_POOL_START="192.168.11.240"
IP_POOL_END="192.168.11.250"

echo -e "${BLUE}What is MetalLB?${NC}"
echo "  - Load balancer implementation for bare metal Kubernetes"
echo "  - In cloud (AWS, GCP), LoadBalancer services get IPs automatically"
echo "  - On-premises/Proxmox needs MetalLB to provide this functionality"
echo

echo -e "${BLUE}How it works:${NC}"
echo "  1. You create a Service with type: LoadBalancer"
echo "  2. MetalLB assigns an IP from the pool (192.168.11.240-250)"
echo "  3. Uses Layer 2 mode (ARP) to announce IP on your network"
echo "  4. Network sees the IP as 'owned' by your cluster"
echo "  5. Traffic to that IP is routed to the service"
echo

echo -e "${BLUE}IP Pool Configuration:${NC}"
echo "  Start: $IP_POOL_START"
echo "  End: $IP_POOL_END"
echo "  Total IPs: 11"
echo
echo -e "${YELLOW}IMPORTANT: Ensure these IPs are:${NC}"
echo "  - Outside your DHCP range"
echo "  - On the same subnet as your nodes (192.168.11.0/24)"
echo "  - Not used by other devices"
echo

read -p "Continue with these IP ranges? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please edit this script to set correct IP ranges"
    exit 1
fi

# ============================================================================
echo -e "${BLUE}Step 1: Install MetalLB${NC}"
echo

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

echo "✓ MetalLB manifests applied"
echo

# ============================================================================
echo "Waiting for MetalLB pods to start..."
echo

kubectl wait --for=condition=ready pod \
    -l app=metallb \
    -n metallb-system \
    --timeout=300s

echo "✓ MetalLB pods are running"
echo

# ============================================================================
echo -e "${BLUE}Step 2: Configure IP Address Pool${NC}"
echo

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - $IP_POOL_START-$IP_POOL_END
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF

echo
echo "✓ IP pool configured"
echo

# ============================================================================
echo "======================================"
echo "MetalLB Installation Complete!"
echo "======================================"
echo

echo "Configuration Summary:"
echo "  IP Pool: $IP_POOL_START - $IP_POOL_END"
echo "  Mode: Layer 2 (ARP)"
echo

echo "Test MetalLB:"
echo "  kubectl create deployment test-nginx --image=nginx"
echo "  kubectl expose deployment test-nginx --port=80 --type=LoadBalancer"
echo "  kubectl get svc test-nginx  # Wait for EXTERNAL-IP"
echo "  # Visit http://<EXTERNAL-IP> in browser"
echo "  kubectl delete svc test-nginx"
echo "  kubectl delete deployment test-nginx"
echo

echo "Next Steps:"
echo "  → Install Ingress NGINX: ./06c-install-ingress.sh"
echo
