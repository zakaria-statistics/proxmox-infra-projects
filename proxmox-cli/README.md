# Proxmox CLI Command Reference

Quick copy-paste command references for Proxmox VE management.

## Files

- **[QUICK-COMMANDS.md](QUICK-COMMANDS.md)** - Complete command reference (all-in-one)
- **[vm-commands.md](vm-commands.md)** - Virtual machine operations
- **[container-commands.md](container-commands.md)** - LXC container operations
- **[storage-commands.md](storage-commands.md)** - Storage and backup management
- **[network-commands.md](network-commands.md)** - Network configuration and troubleshooting
- **[system-commands.md](system-commands.md)** - System administration and monitoring

## Quick Start

### Most Common Commands

```bash
# List everything
qm list                    # VMs
pct list                   # Containers
pvesm status              # Storage

# Start/stop
qm start 100
pct start 100
qm shutdown 100
pct shutdown 100

# Access
qm terminal 100           # VM console
pct console 100           # Container console
pct enter 100             # Container shell

# Status
qm status 100
pct status 100
pvesh get /cluster/resources --type vm
```

### Emergency Commands

```bash
# Force stop
qm stop 100 --skiplock
pct stop 100

# Unlock
qm unlock 100
pct unlock 100

# Reset root password
pveum passwd root@pam

# Check logs
journalctl -f
journalctl -u pvedaemon -f
```

## Project-Specific Quick Commands

### For k8s-platform Project

```bash
# Create all 3 VMs at once
qm create 201 --name k8s-control --memory 2048 --cores 2 --cpu host --net0 virtio,bridge=vmbr0 --scsi0 local-lvm:20 --ostype l26
qm create 202 --name k8s-worker-01 --memory 3072 --cores 3 --cpu host --net0 virtio,bridge=vmbr0 --scsi0 local-lvm:40 --ostype l26
qm create 203 --name k8s-worker-02 --memory 3072 --cores 3 --cpu host --net0 virtio,bridge=vmbr0 --scsi0 local-lvm:40 --ostype l26

# Start all k8s VMs
for vm in 201 202 203; do qm start $vm; done

# Check status
for vm in 201 202 203; do echo "VM $vm:"; qm status $vm; done

# Stop all k8s VMs
for vm in 201 202 203; do qm shutdown $vm; done
```

### For CI/CD Platform

```bash
# Create GitLab VM
qm create 301 --name gitlab-vm --memory 4096 --cores 4 --cpu host --net0 virtio,bridge=vmbr0 --scsi0 local-lvm:50 --ostype l26

# Or GitLab container
pct create 301 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname gitlab \
  --memory 4096 \
  --cores 4 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.11.50/24,gw=192.168.11.1 \
  --storage local-lvm \
  --rootfs local-lvm:50
```

## Command Patterns

### Bulk Operations

```bash
# Pattern for all VMs
for vm in $(qm list | tail -n +2 | awk '{print $1}'); do
  COMMAND_HERE
done

# Pattern for specific range
for vm in {201..203}; do
  qm start $vm
done

# Pattern for specific VMs
for vm in 201 202 203; do
  qm status $vm
done
```

### Information Gathering

```bash
# Get VM/container details in JSON
pvesh get /cluster/resources --type vm --output-format json

# Parse with jq
pvesh get /cluster/resources --type vm --output-format json | jq -r '.[] | "\(.vmid) \(.name) \(.status)"'

# Count running VMs
qm list | grep running | wc -l
```

## File Locations

```
/etc/pve/                       # Proxmox config (cluster filesystem)
├── qemu-server/                # VM configs
├── lxc/                        # Container configs
├── storage.cfg                 # Storage config
├── user.cfg                    # Users
└── firewall/                   # Firewall rules

/var/lib/vz/                    # Proxmox data
├── dump/                       # Backups
├── images/                     # VM disks
└── template/
    ├── iso/                    # ISO images
    └── cache/                  # Container templates
```

## Tips

1. **Always check status before operations**
   ```bash
   qm status 100    # before starting/stopping
   ```

2. **Use --help for any command**
   ```bash
   qm --help
   pct --help
   pvesm --help
   ```

3. **Save configs before major changes**
   ```bash
   qm config 100 > /root/vm-100-backup.conf
   ```

4. **Monitor logs during operations**
   ```bash
   journalctl -f
   ```

5. **Use tab completion**
   ```bash
   qm st<TAB>        # completes to 'qm start'
   qm status 1<TAB>  # shows VMs starting with 1
   ```

## Getting Help

```bash
# Command help
qm --help
pct --help
pvesm --help

# Man pages
man qm
man pct
man pvesm

# Proxmox documentation
# https://pve.proxmox.com/pve-docs/
```
