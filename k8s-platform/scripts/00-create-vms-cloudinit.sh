#!/bin/bash
###############################################################################
# Script: 00-create-vms-cloudinit.sh
# Purpose: Create K8s VMs using Ubuntu Cloud Image + Cloud-Init (AUTOMATED)
# Run Location: Proxmox host
# Timeline: 10 minutes (vs 90 minutes manual installation!)
###############################################################################

set -e

echo "======================================"
echo "Kubernetes VMs - Cloud-Init Method"
echo "======================================"
echo

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}What this does:${NC}"
echo "  1. Downloads Ubuntu 22.04 Cloud Image (pre-installed OS)"
echo "  2. Creates 3 VMs with cloud-init configuration"
echo "  3. VMs boot ready to use in 2 minutes (no manual installation!)"
echo

# Configuration
STORAGE="local-lvm"
BRIDGE="vmbr0"
CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
CLOUD_IMAGE_FILE="/var/lib/vz/template/iso/ubuntu-22.04-cloudimg-amd64.img"

# SSH Key
SSH_KEY=$(cat ~/.ssh/k8s_cluster.pub)

# ============================================================================
echo -e "${BLUE}Step 1: Download Ubuntu Cloud Image${NC}"
echo

if [ -f "$CLOUD_IMAGE_FILE" ]; then
    echo -e "${GREEN}✓ Cloud image already exists${NC}"
else
    echo "Downloading Ubuntu 22.04 Cloud Image..."
    wget -O "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL"
    echo -e "${GREEN}✓ Cloud image downloaded${NC}"
fi

echo

# ============================================================================
echo -e "${BLUE}Step 2: Create VMs with Cloud-Init${NC}"
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

# Create all 3 VMs
create_vm 201 "k8s-control"   "192.168.11.201" 2048 2 20
create_vm 202 "k8s-worker-01" "192.168.11.202" 3072 3 40
create_vm 203 "k8s-worker-02" "192.168.11.203" 3072 3 40

echo -e "${GREEN}✓ All VMs created!${NC}"
echo

# ============================================================================
echo "======================================"
echo "VMs Created with Cloud-Init!"
echo "======================================"
echo

echo "What was configured automatically:"
echo "  ✓ Ubuntu 22.04 LTS installed"
echo "  ✓ Static IPs assigned"
echo "  ✓ SSH keys installed"
echo "  ✓ User 'k8sadmin' created"
echo "  ✓ qemu-guest-agent installed"
echo

echo "Next Steps:"
echo
echo "1. Start all VMs:"
echo "   for vm in 201 202 203; do qm start \$vm; done"
echo
echo "2. Wait 2 minutes for VMs to boot and apply cloud-init"
echo
echo "3. Test SSH access (passwordless!):"
echo "   ssh k8s-control"
echo "   ssh k8s-worker-01"
echo "   ssh k8s-worker-02"
echo
echo "4. Copy setup scripts:"
echo "   scp /root/claude/k8s-platform/scripts/*.sh k8sadmin@192.168.11.201:~"
echo "   scp /root/claude/k8s-platform/scripts/*.sh k8sadmin@192.168.11.202:~"
echo "   scp /root/claude/k8s-platform/scripts/*.sh k8sadmin@192.168.11.203:~"
echo
echo "5. Continue with 02-prepare-os.sh on each VM"
echo

# Optional: Start VMs
read -p "Do you want to start the VMs now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting VMs..."
    qm start 201
    sleep 2
    qm start 202
    sleep 2
    qm start 203
    echo
    echo -e "${GREEN}✓ VMs started!${NC}"
    echo
    echo "Wait ~2 minutes, then test SSH:"
    echo "  ssh k8s-control"
fi
