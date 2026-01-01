#!/bin/bash
###############################################################################
# Script: 00-create-workers-cloudinit.sh
# Purpose: Create ONLY worker VMs (202, 203) using Cloud-Init
# Run Location: Proxmox host
# Note: Control plane (201) already exists - skip it
###############################################################################

set -e

echo "======================================"
echo "K8s Worker VMs - Cloud-Init Method"
echo "======================================"
echo

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
STORAGE="local-lvm"
BRIDGE="vmbr0"
CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
CLOUD_IMAGE_FILE="/var/lib/vz/template/iso/ubuntu-22.04-cloudimg-amd64.img"

# SSH Key
SSH_KEY_FILE="$HOME/.ssh/k8s_cluster.pub"

if [ ! -f "$SSH_KEY_FILE" ]; then
    echo -e "${RED}ERROR: SSH key not found at $SSH_KEY_FILE${NC}"
    exit 1
fi

# ============================================================================
echo -e "${BLUE}Step 1: Check for existing VMs${NC}"
echo

for vmid in 202 203; do
    if qm status $vmid &>/dev/null; then
        echo -e "${YELLOW}WARNING: VM $vmid already exists!${NC}"
        echo "You must destroy it first:"
        echo "  qm stop $vmid"
        echo "  qm destroy $vmid"
        echo
        read -p "Destroy VM $vmid now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            qm stop $vmid 2>/dev/null || true
            sleep 2
            qm destroy $vmid
            echo -e "${GREEN}✓ VM $vmid destroyed${NC}"
        else
            echo "Please destroy VMs manually, then run this script again."
            exit 1
        fi
    fi
done

echo

# ============================================================================
echo -e "${BLUE}Step 2: Download Ubuntu Cloud Image${NC}"
echo

if [ -f "$CLOUD_IMAGE_FILE" ]; then
    echo -e "${GREEN}✓ Cloud image already exists${NC}"
else
    echo "Downloading Ubuntu 22.04 Cloud Image (~700MB)..."
    wget -O "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL"
    echo -e "${GREEN}✓ Cloud image downloaded${NC}"
fi

echo

# ============================================================================
echo -e "${BLUE}Step 3: Create Worker VMs${NC}"
echo

create_vm() {
    local VMID=$1
    local NAME=$2
    local IP=$3
    local MEMORY=$4
    local CORES=$5
    local DISK=$6

    echo -e "${GREEN}Creating VM $VMID: $NAME${NC}"

    # Create VM
    qm create $VMID \
        --name $NAME \
        --memory $MEMORY \
        --cores $CORES \
        --cpu host \
        --net0 virtio,bridge=$BRIDGE \
        --serial0 socket \
        --vga serial0 \
        --agent enabled=1 \
        --ostype l26

    # Import cloud image as disk
    qm importdisk $VMID $CLOUD_IMAGE_FILE $STORAGE

    # Attach disk
    qm set $VMID --scsihw virtio-scsi-pci
    qm set $VMID --scsi0 ${STORAGE}:vm-${VMID}-disk-0

    # Resize disk
    qm resize $VMID scsi0 ${DISK}G

    # Add cloud-init drive
    qm set $VMID --ide2 ${STORAGE}:cloudinit

    # Set boot disk
    qm set $VMID --boot order=scsi0

    # Cloud-init configuration
    qm set $VMID --ciuser k8sadmin
    qm set $VMID --cipassword $(openssl rand -base64 12)  # Random password
    qm set $VMID --sshkeys ~/.ssh/k8s_cluster.pub
    qm set $VMID --ipconfig0 ip=${IP}/24,gw=192.168.11.1
    qm set $VMID --nameserver "8.8.8.8 8.8.4.4"

    echo "  ✓ VM $VMID created: $NAME ($IP)"
    echo
}

# Create ONLY worker VMs (skip 201 - control plane)
create_vm 202 "k8s-worker-01" "192.168.11.202" 3072 3 40
create_vm 203 "k8s-worker-02" "192.168.11.203" 3072 3 40

echo -e "${GREEN}✓ Worker VMs created!${NC}"
echo

# ============================================================================
echo "======================================"
echo "Worker VMs Created!"
echo "======================================"
echo

echo "What was configured:"
echo "  ✓ Ubuntu 22.04 LTS (cloud image)"
echo "  ✓ Static IPs: 192.168.11.202-203"
echo "  ✓ SSH keys installed"
echo "  ✓ User 'k8sadmin' with sudo"
echo "  ✓ QEMU guest agent"
echo

echo "Next Steps:"
echo
echo "1. Start worker VMs:"
echo "   qm start 202"
echo "   qm start 203"
echo
echo "2. Wait 2-3 minutes for cloud-init"
echo
echo "3. Test SSH:"
echo "   ssh k8s-worker-01"
echo "   ssh k8s-worker-02"
echo
echo "4. Copy scripts to workers:"
echo "   scp /root/claude/k8s-platform/scripts/*.sh k8sadmin@192.168.11.202:~"
echo "   scp /root/claude/k8s-platform/scripts/*.sh k8sadmin@192.168.11.203:~"
echo
echo "5. On each worker:"
echo "   ssh k8s-worker-01"
echo "   sudo ./02-prepare-os.sh"
echo "   sudo ./03-install-kubernetes.sh"
echo
echo "6. Get join command from control plane:"
echo "   ssh k8s-control"
echo "   ./05-get-join-command.sh"
echo
echo "7. Join workers to cluster (run on each worker):"
echo "   sudo kubeadm join ..."
echo

# Optional: Start VMs
read -p "Start worker VMs now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting VMs..."
    qm start 202
    sleep 2
    qm start 203
    echo
    echo -e "${GREEN}✓ Worker VMs started!${NC}"
    echo
    echo "Wait ~2-3 minutes for cloud-init, then test SSH"
fi
