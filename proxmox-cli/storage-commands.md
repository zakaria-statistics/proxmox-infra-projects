# Proxmox Storage Commands - Copy & Paste Reference

## Storage Status

### List all storage
```bash
pvesm status
pvesm status -storage local-lvm
```

### Show storage content
```bash
pvesm list local
pvesm list local-lvm
pvesm list local --content iso
```

### Check free space
```bash
df -h
pvesm status
```

## LVM Management

### List physical volumes
```bash
pvs
pvdisplay
```

### List volume groups
```bash
vgs
vgdisplay
```

### List logical volumes
```bash
lvs
lvdisplay
```

### Extend thin pool (if running out of space)
```bash
# Check current size
lvs

# Extend by 10GB
lvextend -L +10G /dev/pve/data

# Or extend to use all free space
lvextend -l +100%FREE /dev/pve/data
```

### Extend root volume
```bash
lvextend -L +10G /dev/pve/root
resize2fs /dev/pve/root
```

## ISO Management

### List ISOs
```bash
pvesm list local --content iso
ls /var/lib/vz/template/iso/
```

### Download ISO
```bash
curl -s https://releases.ubuntu.com/22.04/ | grep -o 'ubuntu-22.04.*-live-server-amd64.iso' | sort -u
cd /var/lib/vz/template/iso/
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.2.0-amd64-netinst.iso
```

### Remove ISO
```bash
rm /var/lib/vz/template/iso/filename.iso
```

## Backup Management

### List backups
```bash
pvesm list local --content backup
ls /var/lib/vz/dump/
```

### Manual backup
```bash
# Single VM/container
vzdump 100 --storage local --mode snapshot

# All VMs
vzdump --all --storage local

# With compression
vzdump 100 --storage local --mode snapshot --compress zstd
```

### Delete old backups
```bash
# List backups older than 7 days
find /var/lib/vz/dump/ -name "*.vma.zst" -mtime +7 -ls

# Delete backups older than 7 days
find /var/lib/vz/dump/ -name "*.vma.zst" -mtime +7 -delete
```

### Restore from backup
```bash
# VM
qmrestore /var/lib/vz/dump/vzdump-qemu-100-*.vma.zst 100

# Container
pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-*.tar.zst
```

## Disk Operations

### List block devices
```bash
lsblk
fdisk -l
```

### Check disk usage
```bash
df -h
du -sh /var/lib/vz/*
```

### Find large files
```bash
du -ah /var/lib/vz | sort -rh | head -20
```

## Clean Up

### Remove unused disks
```bash
qm rescan
```

### Clean apt cache
```bash
apt clean
apt autoclean
```

### Clean old kernels
```bash
# List installed kernels
dpkg --list | grep linux-image

# Remove old kernel (replace with version)
apt purge linux-image-5.x.x-x-pve
```

### Clean journal logs
```bash
journalctl --disk-usage
journalctl --vacuum-time=7d
journalctl --vacuum-size=500M
```

## Storage Performance

### Test disk speed
```bash
# Write test
dd if=/dev/zero of=/tmp/test bs=1M count=1024 oflag=direct
rm /tmp/test

# Read test
dd if=/dev/sda of=/dev/null bs=1M count=1024 iflag=direct
```

### Check I/O
```bash
iostat -x 1
iotop
```

## Add Storage

### Add NFS storage
```bash
pvesm add nfs nfs-storage --server 192.168.11.10 --export /mnt/share --content backup,iso
```

### Add directory storage
```bash
mkdir -p /mnt/storage
pvesm add dir my-storage --path /mnt/storage --content backup,iso
```

## Storage Allocation

### Check which VMs/containers use which storage
```bash
pvesh get /cluster/resources --type vm --output-format json | jq -r '.[] | "\(.vmid) \(.name) \(.disk/1024/1024/1024|floor)GB"'
```

### Find VM/container by disk
```bash
# Find which VM uses a specific disk
grep -r "vm-100-disk" /etc/pve/
```
