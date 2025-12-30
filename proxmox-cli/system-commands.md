# Proxmox System Commands - Copy & Paste Reference

## System Information

### Proxmox version
```bash
pveversion -v
cat /etc/pve/corosync.conf
```

### Kernel version
```bash
uname -a
uname -r
```

### Hardware info
```bash
lscpu              # CPU
free -h            # Memory
lsblk              # Disks
lspci              # PCI devices
lsusb              # USB devices
```

### System uptime
```bash
uptime
uptime -p
```

## Resource Monitoring

### CPU usage
```bash
top
htop
mpstat 1
```

### Memory usage
```bash
free -h
vmstat 1
```

### Disk usage
```bash
df -h
du -sh /*
```

### I/O statistics
```bash
iostat -x 1
iotop
```

### All resources
```bash
# Simple
top

# Advanced
htop
glances
```

## Services

### Proxmox services
```bash
# Status
systemctl status pvedaemon
systemctl status pveproxy
systemctl status pvestatd
systemctl status pve-cluster

# Restart
systemctl restart pvedaemon
systemctl restart pveproxy
systemctl restart pvestatd

# Enable/disable
systemctl enable pvedaemon
systemctl disable pvedaemon
```

### All services
```bash
systemctl list-units --type=service
systemctl list-unit-files --type=service
```

## Logs

### View logs
```bash
# Real-time system log
journalctl -f

# Proxmox daemon logs
journalctl -u pvedaemon -f
journalctl -u pveproxy -f

# Last 100 lines
journalctl -n 100

# Logs from last boot
journalctl -b

# Logs for specific service
journalctl -u qemu-server@100 -f
journalctl -u pve-container@100 -f
```

### Log files
```bash
tail -f /var/log/syslog
tail -f /var/log/daemon.log
cat /var/log/pve/tasks/active
```

### Clear journal logs
```bash
journalctl --disk-usage
journalctl --vacuum-time=7d
journalctl --vacuum-size=500M
```

## Updates

### Update package list
```bash
apt update
```

### List upgradable packages
```bash
apt list --upgradable
```

### Upgrade packages
```bash
apt upgrade
apt dist-upgrade
```

### Check for Proxmox updates
```bash
pveupgrade
```

### Update Proxmox (full)
```bash
apt update
apt dist-upgrade
```

### Remove old packages
```bash
apt autoremove
apt autoclean
```

## Repository Management

### List repositories
```bash
cat /etc/apt/sources.list
cat /etc/apt/sources.list.d/*
```

### Add Proxmox no-subscription repo (free)
```bash
# Comment out enterprise repo
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

apt update
```

## Users and Permissions

### List users
```bash
pveum user list
cat /etc/pve/user.cfg
```

### Add user
```bash
pveum user add user@pam --password <password>
pveum user add user@pve --password <password>
```

### Change password
```bash
pveum passwd user@pam
passwd root      # root password
```

### List permissions
```bash
pveum acl list
```

## Tasks

### List running tasks
```bash
pvesh get /cluster/tasks
```

### View task log
```bash
cat /var/log/pve/tasks/active
ls -lh /var/log/pve/tasks/
```

## Cluster (if using cluster)

### Cluster status
```bash
pvecm status
pvecm nodes
```

### Cluster info
```bash
cat /etc/pve/corosync.conf
```

## Time and Date

### Show time
```bash
date
timedatectl
```

### Set timezone
```bash
timedatectl list-timezones
timedatectl set-timezone America/New_York
```

### Sync time
```bash
systemctl status chronyd
chronyc tracking
```

## Certificate Management

### View certificates
```bash
pveum cert info
ls -l /etc/pve/nodes/*/pve-ssl.*
```

### Renew self-signed certificate
```bash
pveum cert create --force
```

## Backup Proxmox Configuration

### Backup /etc/pve
```bash
tar czf /root/pve-config-backup-$(date +%Y%m%d).tar.gz /etc/pve
```

### Backup complete system config
```bash
tar czf /root/system-backup-$(date +%Y%m%d).tar.gz \
  /etc/pve \
  /etc/network/interfaces \
  /etc/hosts \
  /etc/hostname \
  /etc/resolv.conf
```

## Performance Tuning

### CPU governor
```bash
# Show current
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Set to performance
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Make permanent
apt install cpufrequtils
echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
systemctl restart cpufrequtils
```

### Swappiness
```bash
# Show current
cat /proc/sys/vm/swappiness

# Set to 10 (less swap usage)
sysctl vm.swappiness=10
echo "vm.swappiness=10" >> /etc/sysctl.conf
```

### I/O scheduler (SSD)
```bash
# Show current
cat /sys/block/sda/queue/scheduler

# Set to none (best for NVMe/SSD)
echo none > /sys/block/sda/queue/scheduler

# Make permanent
echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="none"' > /etc/udev/rules.d/60-scheduler.rules
```

## Reboot and Shutdown

### Reboot
```bash
reboot
systemctl reboot
```

### Shutdown
```bash
shutdown -h now
systemctl poweroff
```

### Schedule reboot
```bash
shutdown -r +10        # reboot in 10 minutes
shutdown -r 02:00      # reboot at 2 AM
```

## Troubleshooting

### Check system health
```bash
dmesg | tail -50
journalctl -p err -b
```

### Check disk errors
```bash
smartctl -a /dev/sda
dmesg | grep -i error
```

### Check memory errors
```bash
grep -i error /var/log/syslog
dmesg | grep -i memory
```

### Reset to factory (DANGER!)
```bash
# This will DELETE everything!
# Only use if you want to completely reinstall
apt purge proxmox-ve
rm -rf /etc/pve
```

## SSH

### Generate SSH keys
```bash
ssh-keygen -t ed25519
```

### Copy SSH key to remote
```bash
ssh-copy-id root@192.168.11.100
```

### SSH without password
```bash
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
```

## Miscellaneous

### Get public IP
```bash
curl ifconfig.me
curl icanhazip.com
```

### Download files
```bash
wget <url>
curl -O <url>
```

### Find files
```bash
find / -name "filename"
find /var -type f -size +100M  # files larger than 100MB
```

### Disk cleanup
```bash
apt clean
apt autoclean
apt autoremove
journalctl --vacuum-time=7d
find /var/lib/vz/dump -name "*.vma.*" -mtime +30 -delete
```

### Check open ports
```bash
ss -tuln
netstat -tuln
```

### Process management
```bash
ps aux | grep <name>
kill <pid>
killall <process-name>
```
