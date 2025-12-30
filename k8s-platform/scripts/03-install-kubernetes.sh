#!/bin/bash
###############################################################################
# Script: 03-install-kubernetes.sh
# Purpose: Install container runtime and Kubernetes components
# Run Location: ALL 3 VMs (control plane + workers)
# Timeline: 30-60 minutes per VM (depends on download speed)
###############################################################################

set -e  # Exit on any error

echo "======================================"
echo "Kubernetes Installation"
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

# Kubernetes version
K8S_VERSION="v1.28"
echo "Installing Kubernetes $K8S_VERSION"
echo

# ============================================================================
echo -e "${BLUE}Step 1: Install containerd${NC}"
echo "Why: containerd is the container runtime that actually runs containers"
echo "  - Lightweight and focused (no unnecessary features like Docker CLI)"
echo "  - Industry standard (used by major cloud providers)"
echo "  - Native Kubernetes support (CRI - Container Runtime Interface)"
echo

apt-get update
apt-get install -y containerd

# Create containerd directory
mkdir -p /etc/containerd

# Generate default configuration
containerd config default | tee /etc/containerd/config.toml

echo "✓ containerd installed"
echo

# ============================================================================
echo -e "${BLUE}Step 2: Configure containerd for Kubernetes${NC}"
echo "Why: We need to configure the cgroup driver for proper resource management"
echo "  - SystemdCgroup=true: Use systemd for cgroup management"
echo "  - This matches what kubelet expects"
echo "  - Prevents conflicts between systemd and cgroupfs"
echo

# Modify containerd config to use systemd cgroup driver
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd to apply changes
systemctl restart containerd
systemctl enable containerd

# Verify containerd is running
if systemctl is-active --quiet containerd; then
    echo "✓ containerd configured and running"
else
    echo "✗ containerd failed to start"
    exit 1
fi
echo

# ============================================================================
echo -e "${BLUE}Step 3: Add Kubernetes Package Repository${NC}"
echo "Why: Ubuntu default repos don't have Kubernetes packages"
echo "  We add Google's official Kubernetes repository for:"
echo "  - Latest stable versions"
echo "  - Security updates"
echo "  - Verified package signatures"
echo

# Create keyrings directory
mkdir -p /etc/apt/keyrings

# Download Kubernetes GPG key
curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/ /" | \
    tee /etc/apt/sources.list.d/kubernetes.list

# Update package list
apt-get update

echo "✓ Kubernetes repository added"
echo

# ============================================================================
echo -e "${BLUE}Step 4: Install Kubernetes Components${NC}"
echo "What we're installing:"
echo "  - kubelet: Node agent that runs on every node"
echo "    * Manages containers on this node"
echo "    * Reports node status to control plane"
echo "    * Receives instructions from API server"
echo
echo "  - kubeadm: Cluster bootstrapping tool"
echo "    * Initializes control plane"
echo "    * Joins nodes to cluster"
echo "    * Manages certificates"
echo
echo "  - kubectl: Command-line tool for Kubernetes"
echo "    * Interact with cluster (create, read, update, delete resources)"
echo "    * Only strictly needed on control plane, but useful on all nodes"
echo

apt-get install -y kubelet kubeadm kubectl

# Prevent automatic updates (we want to control when to upgrade)
apt-mark hold kubelet kubeadm kubectl

echo "✓ Kubernetes components installed"
echo

# ============================================================================
echo -e "${BLUE}Step 5: Enable kubelet Service${NC}"
echo "Why: kubelet needs to start automatically on boot"
echo "  - It's not started immediately (no cluster to join yet)"
echo "  - Will start after kubeadm init/join"
echo

systemctl enable kubelet

echo "✓ kubelet service enabled"
echo

# ============================================================================
echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo

# Display installed versions
echo "Installed Versions:"
echo "  kubelet: $(kubelet --version | awk '{print $2}')"
echo "  kubeadm: $(kubeadm version -o short)"
echo "  kubectl: $(kubectl version --client -o yaml | grep gitVersion | awk '{print $2}')"
echo "  containerd: $(containerd --version | awk '{print $3}')"
echo

echo "Next Steps:"
echo
echo "If this is VM 201 (k8s-control):"
echo "  → Run: ./04-init-control-plane.sh"
echo
echo "If this is a worker node:"
echo "  → Wait for control plane initialization"
echo "  → Then get join command from control plane"
echo

# Display node info
echo "Node Information:"
echo "  Hostname: $(hostname)"
echo "  IP: $(hostname -I | awk '{print $1}')"
echo
