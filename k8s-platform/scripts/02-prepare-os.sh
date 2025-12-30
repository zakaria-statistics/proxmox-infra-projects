#!/bin/bash
###############################################################################
# Script: 02-prepare-os.sh
# Purpose: Prepare OS for Kubernetes installation
# Run Location: ALL 3 VMs (control plane + workers)
# Timeline: 15 minutes per VM
###############################################################################

set -e  # Exit on any error

echo "======================================"
echo "Kubernetes OS Preparation"
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

echo -e "${BLUE}Step 1: System Update${NC}"
echo "Why: Ensure all packages are up-to-date for security and compatibility"
echo

apt-get update
apt-get upgrade -y

echo "✓ System updated"
echo

# ============================================================================
echo -e "${BLUE}Step 2: Disable Swap${NC}"
echo "Why: Kubernetes requires swap to be disabled for:"
echo "  - Predictable performance (no swapping slows pods)"
echo "  - Memory limit enforcement (pods should use limits, not swap)"
echo "  - Container isolation (swap can leak data between containers)"
echo

# Turn off swap immediately
swapoff -a

# Comment out swap entries in fstab to persist across reboots
sed -i '/ swap / s/^/#/' /etc/fstab

# Verify swap is off
if [ "$(swapon -s | wc -l)" -eq 0 ]; then
    echo "✓ Swap disabled successfully"
else
    echo "✗ Failed to disable swap"
    exit 1
fi
echo

# ============================================================================
echo -e "${BLUE}Step 3: Load Kernel Modules${NC}"
echo "Why: These modules are required for container networking:"
echo "  - overlay: Enables overlay filesystem for container image layers"
echo "  - br_netfilter: Allows iptables to process bridged network traffic"
echo

# Create module configuration file
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Load modules immediately (without reboot)
modprobe overlay
modprobe br_netfilter

# Verify modules are loaded
if lsmod | grep -q overlay && lsmod | grep -q br_netfilter; then
    echo "✓ Kernel modules loaded successfully"
else
    echo "✗ Failed to load kernel modules"
    exit 1
fi
echo

# ============================================================================
echo -e "${BLUE}Step 4: Configure Kernel Parameters${NC}"
echo "Why: These settings enable proper network routing for Kubernetes:"
echo "  - net.bridge.bridge-nf-call-iptables: Bridge traffic goes through iptables"
echo "  - net.ipv4.ip_forward: Enable packet forwarding between interfaces"
echo "    (Required for pods to communicate across nodes)"
echo

# Create sysctl configuration
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply settings immediately
sysctl --system

# Verify settings
if [ "$(sysctl net.ipv4.ip_forward | awk '{print $3}')" -eq 1 ]; then
    echo "✓ Kernel parameters configured successfully"
else
    echo "✗ Failed to configure kernel parameters"
    exit 1
fi
echo

# ============================================================================
echo -e "${BLUE}Step 5: Install Required Packages${NC}"
echo "Why: These are prerequisites for Kubernetes installation:"
echo "  - apt-transport-https: Allows apt to use HTTPS repositories"
echo "  - ca-certificates: SSL certificates for secure connections"
echo "  - curl: Download files from the internet"
echo "  - gnupg: Verify package signatures"
echo

apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo "✓ Required packages installed"
echo

# ============================================================================
echo -e "${BLUE}Step 6: Configure Time Synchronization${NC}"
echo "Why: Kubernetes requires accurate time across all nodes for:"
echo "  - Certificate validation (timestamps must match)"
echo "  - Log correlation (debugging requires accurate timestamps)"
echo "  - etcd consensus (distributed database needs synchronized clocks)"
echo

# Install and enable NTP
apt-get install -y chrony
systemctl enable chrony
systemctl start chrony

# Wait a moment for time sync
sleep 2

# Verify time sync
if systemctl is-active --quiet chrony; then
    echo "✓ Time synchronization configured"
    echo "  Current time: $(date)"
else
    echo "⚠ Warning: Time sync may not be working properly"
fi
echo

# ============================================================================
echo "======================================"
echo "OS Preparation Complete!"
echo "======================================"
echo
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "Swap Status: $(free -h | grep Swap | awk '{print $2}')"
echo
echo "Next Steps:"
echo "1. Verify this VM's network connectivity:"
echo "   ping -c 3 8.8.8.8"
echo
echo "2. Repeat this script on the other VMs if not done already"
echo
echo "3. Once all VMs are prepared, run on EACH VM:"
echo "   ./03-install-kubernetes.sh"
echo
