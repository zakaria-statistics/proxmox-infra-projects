# Proxmox VM Commands - Copy & Paste Reference

## Quick VM Operations

### List all VMs
```bash
qm list
```

### Create a VM (manual command)
```bash
# Basic template - customize as needed
qm create 100 --name my-vm --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 --scsi0 local-lvm:20

# For k8s control plane
qm create 201 --name k8s-control --memory 2048 --cores 2 --cpu host --net0 virtio,bridge=vmbr0 --scsi0 local-lvm:20 --ostype l26

# For k8s worker
qm create 202 --name k8s-worker-01 --memory 3072 --cores 3 --cpu host --net0 virtio,bridge=vmbr0 --scsi0 local-lvm:40 --ostype l26
```

### Start/Stop VMs
```bash
qm start 100
qm shutdown 100
qm stop 100         # force stop
qm reboot 100
```

### VM Configuration
```bash
qm config 100       # show config
qm set 100 --memory 4096
qm set 100 --cores 4
qm set 100 --onboot 1    # start on boot
```

### Delete VM
```bash
qm stop 100
qm destroy 100 --purge   # includes disks
```

### VM Console
```bash
qm terminal 100     # serial console
```

### Clone VM
```bash
qm clone 100 101 --name cloned-vm
qm clone 100 101 --full   # full clone (not linked)
```

## VM Disk Operations

### Attach ISO
```bash
qm set 100 --ide2 local:iso/ubuntu-22.04.3-live-server-amd64.iso,media=cdrom
```

### Remove ISO
```bash
qm set 100 --delete ide2
```

### Add disk
```bash
qm set 100 --scsi1 local-lvm:10   # add 10GB disk
```

### Resize disk
```bash
qm resize 100 scsi0 +10G
```

## Snapshots

### Create snapshot
```bash
qm snapshot 100 my-snapshot --description "Before changes"
```

### List snapshots
```bash
qm listsnapshot 100
```

### Rollback
```bash
qm rollback 100 my-snapshot
```

### Delete snapshot
```bash
qm delsnapshot 100 my-snapshot
```

## VM Import/Export

### Backup
```bash
vzdump 100 --storage local --mode snapshot
```

### Restore
```bash
qmrestore /var/lib/vz/dump/vzdump-qemu-100-*.vma.zst 100
```

## Bulk Operations

### Stop all VMs
```bash
for vm in $(qm list | tail -n +2 | awk '{print $1}'); do qm shutdown $vm; done
```

### Start all VMs
```bash
for vm in $(qm list | tail -n +2 | awk '{print $1}'); do qm start $vm; done
```

### List all VM IPs
```bash
qm list | tail -n +2 | while read vmid status name; do
  echo "VM $vmid ($name): $(qm agent $vmid network-get-interfaces 2>/dev/null | grep -oP '(?<="ip-address":")[^"]*' | grep -v "127.0.0.1" | head -1)"
done
```
