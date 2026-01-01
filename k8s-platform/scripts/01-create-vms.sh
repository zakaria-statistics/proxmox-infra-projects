#!/bin/bash
###############################################################################
# Script: 01-create-vms.sh
# Purpose: Create 3 VMs on Proxmox for Kubernetes cluster
# Run Location: Proxmox host
# Timeline: 30 minutes (including OS installation)
###############################################################################

set -e  # Exit on any error

echo "======================================"
echo "Kubernetes Cluster VM Creation"
echo "======================================"
echo

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
STORAGE="local-lvm"  # Storage location for VM disks
ISO_STORAGE="local"  # Storage location for ISO files
BRIDGE="vmbr0"       # Network bridge

echo -e "${YELLOW}Configuration:${NC}"
echo "  Storage: $STORAGE"
echo "  Network Bridge: $BRIDGE"
echo

# VM 201: Control Plane
echo -e "${GREEN}Creating VM 201: k8s-control (Control Plane)${NC}"
echo "  Why: Runs Kubernetes management components (API, scheduler, etcd)"
echo "  Resources: 2GB RAM, 2 CPU cores, 20GB disk"
echo

qm create 201 \
  --name k8s-control \
  --memory 2048 \
  --cores 2 \
  --cpu host \
  --net0 virtio,bridge=$BRIDGE \
  --scsihw virtio-scsi-pci \
  --scsi0 $STORAGE:20 \
  --boot order=scsi0 \
  --ostype l26 \
  --agent enabled=1

# Explanation of flags:
# --name: VM hostname
# --memory: RAM in MB (2GB for control plane)
# --cores: Number of CPU cores
# --cpu host: Pass through host CPU features for better performance
# --net0: Network adapter (virtio is fastest for Linux)
# --bridge: Connect to main network bridge
# --scsihw: SCSI controller type (virtio for performance)
# --scsi0: Disk allocation (20GB on local-lvm)
# --boot: Boot from first SCSI disk
# --ostype: Linux kernel 2.6+ (modern Linux)
# --agent: Enable QEMU guest agent for better integration

echo "✓ Control plane VM created (ID: 201)"
echo

# VM 202: Worker Node 1
echo -e "${GREEN}Creating VM 202: k8s-worker-01 (Worker Node 1)${NC}"
echo "  Why: Runs your application containers/pods"
echo "  Resources: 3GB RAM, 3 CPU cores, 40GB disk"
echo

qm create 202 \
  --name k8s-worker-01 \
  --memory 3072 \
  --cores 3 \
  --cpu host \
  --net0 virtio,bridge=$BRIDGE \
  --scsihw virtio-scsi-pci \
  --scsi0 $STORAGE:40 \
  --boot order=scsi0 \
  --ostype l26 \
  --agent enabled=1

echo "✓ Worker node 1 created (ID: 202)"
echo

# VM 203: Worker Node 2
echo -e "${GREEN}Creating VM 203: k8s-worker-02 (Worker Node 2)${NC}"
echo "  Why: Provides redundancy and additional capacity"
echo "  Resources: 3GB RAM, 3 CPU cores, 40GB disk"
echo

qm create 203 \
  --name k8s-worker-02 \
  --memory 3072 \
  --cores 3 \
  --cpu host \
  --net0 virtio,bridge=$BRIDGE \
  --scsihw virtio-scsi-pci \
  --scsi0 $STORAGE:40 \
  --boot order=scsi0 \
  --ostype l26 \
  --agent enabled=1

echo "✓ Worker node 2 created (ID: 203)"
echo

# ============================================================================
echo "======================================"
echo "ISO Attachment"
echo "======================================"
echo
echo -e "${BLUE}What happens now:${NC}"
echo "  1. VMs are created with empty disks (no OS yet)"
echo "  2. ISO file is attached as virtual CD/DVD drive"
echo "  3. VMs will boot from ISO to install Ubuntu"
echo "  4. After installation, Ubuntu runs from disk"
echo
echo -e "${BLUE}Checking for Ubuntu 22.04 ISO...${NC}"

# Look for any Ubuntu 22.04 ISO
ISO_FILE=$(ls /var/lib/vz/template/iso/ubuntu-22.04*-live-server-amd64.iso 2>/dev/null | head -1)

if [ -n "$ISO_FILE" ]; then
    ISO_NAME=$(basename "$ISO_FILE")
    echo -e "${GREEN}✓ Found: $ISO_NAME${NC}"
    echo
    echo "Attaching ISO to VMs as virtual CD-ROM..."
    echo "  Why --ide2: CD-ROM device slot for boot media"
    echo "  Why media=cdrom: Tells VM this is a CD/DVD drive"
    echo

    # Attach ISO to each VM
    qm set 201 --ide2 $ISO_STORAGE:iso/$ISO_NAME,media=cdrom
    echo "  ✓ VM 201 (k8s-control): ISO attached"

    qm set 202 --ide2 $ISO_STORAGE:iso/$ISO_NAME,media=cdrom
    echo "  ✓ VM 202 (k8s-worker-01): ISO attached"

    qm set 203 --ide2 $ISO_STORAGE:iso/$ISO_NAME,media=cdrom
    echo "  ✓ VM 203 (k8s-worker-02): ISO attached"

    echo
    echo -e "${GREEN}✓ All VMs ready to boot from ISO${NC}"
else
    echo -e "${YELLOW}⚠ No Ubuntu 22.04 ISO found in /var/lib/vz/template/iso/${NC}"
    echo
    echo "Download Ubuntu ISO first:"
    echo "  cd /var/lib/vz/template/iso"
    echo "  wget https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
    echo
    echo "Then attach to VMs:"
    echo "  qm set 201 --ide2 local:iso/ubuntu-22.04.5-live-server-amd64.iso,media=cdrom"
    echo "  qm set 202 --ide2 local:iso/ubuntu-22.04.5-live-server-amd64.iso,media=cdrom"
    echo "  qm set 203 --ide2 local:iso/ubuntu-22.04.5-live-server-amd64.iso,media=cdrom"
    echo
    echo -e "${YELLOW}Skipping automatic ISO attachment...${NC}"
fi

echo

# Summary
echo "======================================"
echo "VM Creation Complete!"
echo "======================================"
echo
echo "Next Steps:"
echo
echo "1. Start VMs and install Ubuntu:"
echo "   - VM 201: IP 192.168.11.201, hostname k8s-control"
echo "   - VM 202: IP 192.168.11.202, hostname k8s-worker-01"
echo "   - VM 203: IP 192.168.11.203, hostname k8s-worker-02"
echo "   - Gateway: 192.168.11.1"
echo "   - DNS: 8.8.8.8 or your router IP"
echo "   - Enable OpenSSH server during installation"
echo "   - Create user: k8sadmin (or your preference)"
echo
echo
echo "2. After OS installation, remove ISO (optional):"
echo "   qm set 201 --delete ide2"
echo "   qm set 202 --delete ide2"
echo "   qm set 203 --delete ide2"
echo
echo "3. Then run 02-prepare-os.sh on EACH VM"
echo

# Optional: Start VMs
read -p "Do you want to start the VMs now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting VMs..."
    qm start 201
    qm start 202
    qm start 203
    echo "✓ VMs started. Access console via Proxmox web UI to install OS"
fi
