# Proxmox CLI Quick Commands Reference

## VM Management

### List VMs/Containers
```bash
# List all VMs
qm list

# List all LXC containers
pct list

# List both VMs and containers
pvesh get /cluster/resources --type vm

# Show VM configuration
qm config <vmid>

# Show container configuration
pct config <vmid>
```

### Create VM
```bash
# Basic VM creation
qm create <vmid> \
  --name <vm-name> \
  --memory <MB> \
  --cores <num> \
  --net0 virtio,bridge=vmbr0 \
  --scsi0 local-lvm:<size>G

# Example: Create Ubuntu VM
qm create 100 \
  --name ubuntu-vm \
  --memory 2048 \
  --cores 2 \
  --cpu host \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:20 \
  --ostype l26 \
  --agent enabled=1
```

### Start/Stop/Delete VMs
```bash
# Start VM
qm start <vmid>

# Stop VM (graceful)
qm stop <vmid>

# Force stop VM
qm stop <vmid> --skiplock

# Shutdown VM
qm shutdown <vmid>

# Reboot VM
qm reboot <vmid>

# Delete VM
qm destroy <vmid>

# Delete VM and all disks
qm destroy <vmid> --purge
```

### Start/Stop/Delete Containers
```bash
# Start container
pct start <vmid>

# Stop container
pct stop <vmid>

# Shutdown container
pct shutdown <vmid>

# Reboot container
pct reboot <vmid>

# Delete container
pct destroy <vmid>

# Delete container and all disks
pct destroy <vmid> --purge
```

### VM Configuration
```bash
# Set CPU cores
qm set <vmid> --cores <num>

# Set memory
qm set <vmid> --memory <MB>

# Add disk
qm set <vmid> --scsi1 local-lvm:<size>G

# Attach ISO
qm set <vmid> --ide2 local:iso/<filename>,media=cdrom

# Remove ISO
qm set <vmid> --delete ide2

# Enable/disable VM on boot
qm set <vmid> --onboot 1  # Enable
qm set <vmid> --onboot 0  # Disable

# Set boot order
qm set <vmid> --boot order=scsi0
```

### Container Configuration
```bash
# Set CPU cores
pct set <vmid> --cores <num>

# Set memory
pct set <vmid> --memory <MB>

# Set disk size
pct resize <vmid> rootfs <size>G

# Enable/disable on boot
pct set <vmid> --onboot 1
```

### VM/Container Information
```bash
# Show VM status
qm status <vmid>

# Show container status
pct status <vmid>

# Show VM current config
qm config <vmid>

# Show pending changes
qm pending <vmid>

# Show VM resource usage
qm monitor <vmid>
```

### Clone VM/Container
```bash
# Clone VM
qm clone <source-vmid> <new-vmid> --name <new-name>

# Full clone (independent copy)
qm clone <source-vmid> <new-vmid> --full

# Clone container
pct clone <source-vmid> <new-vmid> --hostname <new-name>
```

### Migrate VM
```bash
# Migrate VM to another node
qm migrate <vmid> <target-node>

# Online migration
qm migrate <vmid> <target-node> --online
```

### Backup/Restore
```bash
# Backup VM
vzdump <vmid> --storage local --mode snapshot

# Backup all VMs
vzdump --all --storage local

# List backups
pvesh get /nodes/<node>/storage/local/content --content backup

# Restore VM
qmrestore /var/lib/vz/dump/vzdump-qemu-<vmid>-*.vma.zst <new-vmid>
```

---

## Storage Management

### List Storage
```bash
# List all storage
pvesh get /storage

# List storage with details
pvesm status

# Show specific storage
pvesm status --storage <storage-name>
```

### Storage Operations
```bash
# List content in storage
pvesm list <storage-name>

# Show storage allocation
pvesm allocation <storage-name>

# Free space
df -h
lvs  # For LVM
```

### Disk Management
```bash
# List physical volumes
pvs

# List volume groups
vgs

# List logical volumes
lvs

# Show disk usage
lsblk
fdisk -l

# Resize LVM thin pool (if running out of space)
lvextend -L +10G /dev/pve/data
```

### ISO Management
```bash
# List ISOs
pvesm list local --content iso

# Download ISO
cd /var/lib/vz/template/iso
wget <iso-url>

# Example: Download Ubuntu
cd /var/lib/vz/template/iso
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso

# Remove ISO
rm /var/lib/vz/template/iso/<filename>
```

### Container Template Management
```bash
# List available templates
pveam available

# Download template
pveam download local <template-name>

# Example: Download Ubuntu 22.04 LXC template
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# List downloaded templates
pveam list local
```

---

## Network Management

### View Network Configuration
```bash
# Show network interfaces
ip addr show
ip link show

# Show bridges
brctl show

# Show network config
cat /etc/network/interfaces

# Show routing table
ip route show
```

### Configure Network (requires reboot)
```bash
# Edit network configuration
nano /etc/network/interfaces

# Apply network changes (Proxmox 7+)
ifreload -a

# Restart networking (use with caution)
systemctl restart networking
```

### Firewall
```bash
# Show firewall status
pve-firewall status

# Enable firewall
pve-firewall enable

# Disable firewall
pve-firewall disable

# Show firewall rules
cat /etc/pve/firewall/cluster.fw
```

---

## Node Management

### Node Information
```bash
# Show cluster nodes
pvecm nodes

# Show node status
pvesh get /nodes

# Show node resources
pvesh get /nodes/<node>/status

# Show node version
pveversion

# Show kernel version
uname -a
```

### System Resources
```bash
# CPU usage
top
htop

# Memory usage
free -h

# Disk usage
df -h

# Show running processes
ps aux

# Monitor system
vmstat 1
iostat 1
```

### Updates
```bash
# Update package list
apt update

# List available updates
apt list --upgradable

# Upgrade packages
apt upgrade

# Upgrade Proxmox
apt dist-upgrade

# Check for Proxmox updates
pveupgrade
```

### Services
```bash
# Restart Proxmox services
systemctl restart pvedaemon
systemctl restart pveproxy
systemctl restart pvestatd

# Check service status
systemctl status pvedaemon
systemctl status pveproxy

# View logs
journalctl -u pvedaemon -f
journalctl -u pveproxy -f
```

---

## LXC Container Specific

### Create Container
```bash
# Create Ubuntu container
pct create <vmid> \
  local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname <name> \
  --memory <MB> \
  --cores <num> \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-lvm \
  --rootfs local-lvm:<size>

# Example: Create Docker container
pct create 100 \
  local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname docker-host \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.11.100/24,gw=192.168.11.1 \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --features nesting=1 \
  --unprivileged 1
```

### Container Operations
```bash
# Enter container console
pct console <vmid>

# Execute command in container
pct exec <vmid> -- <command>

# Example: Update container
pct exec 100 -- apt update

# Push file to container
pct push <vmid> <local-file> <container-path>

# Pull file from container
pct pull <vmid> <container-path> <local-file>
```

### Container Features
```bash
# Enable nesting (for Docker)
pct set <vmid> --features nesting=1

# Enable FUSE (for AppImage, SSHFS)
pct set <vmid> --features fuse=1

# Enable keyctl (for systemd)
pct set <vmid> --features keyctl=1

# Disable AppArmor (for Docker)
pct set <vmid> --features nesting=1
echo "lxc.apparmor.profile: unconfined" >> /etc/pve/lxc/<vmid>.conf
```

---

## Monitoring & Logging

### Resource Monitoring
```bash
# Show VM resource usage
qm monitor <vmid>

# Show all VMs resource usage
for vm in $(qm list | tail -n +2 | awk '{print $1}'); do
  echo "VM $vm:"; qm status $vm
done

# Container resource usage
pct status <vmid>
```

### Logs
```bash
# VM/Container logs
journalctl -u qemu-server@<vmid> -f
journalctl -u pve-container@<vmid> -f

# System logs
journalctl -f
tail -f /var/log/syslog

# Proxmox task logs
cat /var/log/pve/tasks/*
```

### Tasks
```bash
# List running tasks
pvesh get /cluster/tasks

# Show task status
pvesh get /nodes/<node>/tasks/<upid>/status
```

---

## Useful One-Liners

### Find VMs/Containers
```bash
# Find VM by name
qm list | grep <name>

# Find container by name
pct list | grep <name>

# Find by IP (check configs)
grep -r "192.168.11.100" /etc/pve/nodes/*/qemu-server/
grep -r "192.168.11.100" /etc/pve/nodes/*/lxc/
```

### Bulk Operations
```bash
# Stop all VMs
for vm in $(qm list | tail -n +2 | awk '{print $1}'); do
  qm shutdown $vm
done

# Start all VMs
for vm in $(qm list | tail -n +2 | awk '{print $1}'); do
  qm start $vm
done

# List all IPs
pvesh get /cluster/resources --type vm --output-format json | \
  jq -r '.[] | "\(.vmid) \(.name) \(.status)"'
```

### Cleanup
```bash
# Remove unused disks
qm rescan

# Clean old backups (keep last 3)
find /var/lib/vz/dump -name "*.vma.zst" -mtime +21 -delete

# Clean apt cache
apt clean
apt autoclean
```

---

## Troubleshooting

### VM Won't Start
```bash
# Check VM config
qm config <vmid>

# Check locks
qm unlock <vmid>

# Check logs
journalctl -u qemu-server@<vmid> -n 50

# Start in debug mode
qm start <vmid> --debug
```

### Container Won't Start
```bash
# Check container config
pct config <vmid>

# Check locks
pct unlock <vmid>

# Check logs
journalctl -u pve-container@<vmid> -n 50

# Debug mode
pct start <vmid> --debug
```

### Storage Issues
```bash
# Check storage status
pvesm status

# Rescan storage
qm rescan

# Check disk space
df -h
lvs
vgs
```

### Network Issues
```bash
# Check bridge
brctl show

# Check IP forwarding
sysctl net.ipv4.ip_forward

# Restart networking
systemctl restart networking

# Check firewall
pve-firewall status
iptables -L -n -v
```

---

## Emergency/Recovery

### Reset Root Password (VM)
```bash
# Boot VM to single-user mode or use rescue disk
# Then change password inside VM
```

### Reset Proxmox Web Password
```bash
# Reset root password for Proxmox web UI
pveum passwd root@pam
```

### Recover from Failed Upgrade
```bash
# Fix broken packages
apt --fix-broken install

# Reconfigure packages
dpkg --configure -a

# Force package installation
apt install -f
```

### Backup Configuration
```bash
# Backup Proxmox configuration
tar czf proxmox-config-backup.tar.gz /etc/pve

# Backup VM configs
cp -r /etc/pve/qemu-server /backup/
cp -r /etc/pve/lxc /backup/
```

---

## Performance Tuning

### CPU Governor
```bash
# Show current governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Set to performance
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### I/O Scheduler
```bash
# Show current scheduler
cat /sys/block/sda/queue/scheduler

# Set to none (for SSDs)
echo none > /sys/block/sda/queue/scheduler
```

### Swappiness
```bash
# Show current swappiness
cat /proc/sys/vm/swappiness

# Set lower swappiness (better for VMs)
sysctl vm.swappiness=10
echo "vm.swappiness=10" >> /etc/sysctl.conf
```
