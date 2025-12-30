# Proxmox LXC Container Commands - Copy & Paste Reference

## Quick Container Operations

### List containers
```bash
pct list
```

### Create container
```bash
# Download template first
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Create container
pct create 100 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname my-container \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.11.100/24,gw=192.168.11.1 \
  --storage local-lvm \
  --rootfs local-lvm:8

# Create Docker container (with nesting)
pct create 100 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname docker-host \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.11.100/24,gw=192.168.11.1 \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --features nesting=1 \
  --unprivileged 1
```

### Start/Stop containers
```bash
pct start 100
pct shutdown 100
pct stop 100        # force stop
pct reboot 100
```

### Container access
```bash
pct console 100     # console
pct enter 100       # direct shell
```

### Execute command in container
```bash
pct exec 100 -- apt update
pct exec 100 -- ls -la /root
```

### Container configuration
```bash
pct config 100      # show config
pct set 100 --memory 4096
pct set 100 --cores 4
pct set 100 --onboot 1
```

### Delete container
```bash
pct stop 100
pct destroy 100 --purge
```

## Container Disk Operations

### Resize container disk
```bash
pct resize 100 rootfs +5G
```

### Add mount point
```bash
pct set 100 --mp0 /mnt/shared,mp=/shared
```

## Container Features

### Enable Docker support
```bash
pct set 100 --features nesting=1
```

### Enable FUSE
```bash
pct set 100 --features fuse=1
```

### Disable AppArmor (for Docker)
```bash
echo "lxc.apparmor.profile: unconfined" >> /etc/pve/lxc/100.conf
pct reboot 100
```

## File Transfer

### Copy file to container
```bash
pct push 100 /local/file.txt /root/file.txt
```

### Copy file from container
```bash
pct pull 100 /root/file.txt /local/file.txt
```

## Container Templates

### List available templates
```bash
pveam available
pveam available | grep ubuntu
```

### Download template
```bash
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
pveam download local debian-12-standard_12.0-1_amd64.tar.zst
```

### List downloaded templates
```bash
pveam list local
ls /var/lib/vz/template/cache/
```

## Snapshots

### Create snapshot
```bash
pct snapshot 100 my-snapshot --description "Before changes"
```

### List snapshots
```bash
pct listsnapshot 100
```

### Rollback
```bash
pct rollback 100 my-snapshot
```

### Delete snapshot
```bash
pct delsnapshot 100 my-snapshot
```

## Backup/Restore

### Backup container
```bash
vzdump 100 --storage local --mode snapshot
```

### Restore container
```bash
pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-*.tar.zst
```

## Bulk Operations

### Stop all containers
```bash
for ct in $(pct list | tail -n +2 | awk '{print $1}'); do pct shutdown $ct; done
```

### Start all containers
```bash
for ct in $(pct list | tail -n +2 | awk '{print $1}'); do pct start $ct; done
```

### Update all containers
```bash
for ct in $(pct list | tail -n +2 | awk '{print $1}'); do
  echo "Updating CT $ct..."
  pct exec $ct -- apt update && pct exec $ct -- apt upgrade -y
done
```
