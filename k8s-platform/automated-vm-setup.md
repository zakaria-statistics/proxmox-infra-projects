# Automated VM Setup Methods

## Comparison: Manual UI vs Cloud-Init

| Aspect | Manual UI Installation | Cloud-Init (Automated) |
|--------|----------------------|------------------------|
| **Time per VM** | 30 minutes | 2 minutes |
| **Total time (3 VMs)** | 90 minutes | 6 minutes |
| **User interaction** | Click through installer | Run one script |
| **Configuration** | Manual for each VM | YAML file (repeatable) |
| **Consistency** | Prone to errors | Identical every time |
| **SSH keys** | Add after install | Pre-configured |
| **Network** | Manual setup | Auto-configured |
| **Industry standard** | Traditional | Cloud-native |

## Quick Start: Cloud-Init Method

### 1. Run the Script
```bash
cd /root/claude/k8s-platform/scripts
./00-create-vms-cloudinit.sh
```

### What It Does:
1. Downloads Ubuntu 22.04 Cloud Image (~700MB, one-time)
2. Creates 3 VMs with all settings pre-configured
3. Injects your SSH key automatically
4. Configures static IPs
5. VMs boot ready to use!

### 2. Start VMs
```bash
for vm in 201 202 203; do qm start $vm; done
```

### 3. Wait 2 Minutes
Cloud-init applies configuration on first boot

### 4. Test Access (Passwordless!)
```bash
ssh k8s-control
ssh k8s-worker-01
ssh k8s-worker-02
```

### 5. Continue with K8s Setup
```bash
# Copy scripts to VMs
scp /root/claude/k8s-platform/scripts/*.sh k8sadmin@192.168.11.201:~
scp /root/claude/k8s-platform/scripts/*.sh k8sadmin@192.168.11.202:~
scp /root/claude/k8s-platform/scripts/*.sh k8sadmin@192.168.11.203:~

# Run on each VM
ssh k8s-control
sudo ./02-prepare-os.sh
sudo ./03-install-kubernetes.sh
```

## How Cloud-Init Works

1. **Cloud Image**: Pre-installed Ubuntu (no installation needed)
2. **Cloud-Init Drive**: Virtual drive with configuration (YAML)
3. **First Boot**: Cloud-init reads config and applies it
4. **Result**: Fully configured VM in 2 minutes

## What Gets Configured Automatically

- ✅ Hostname (k8s-control, k8s-worker-01, k8s-worker-02)
- ✅ Static IP addresses (192.168.11.201-203)
- ✅ Gateway & DNS (192.168.11.1, 8.8.8.8)
- ✅ User 'k8sadmin' with sudo access
- ✅ SSH keys installed (passwordless access)
- ✅ QEMU Guest Agent installed
- ✅ System updated on first boot
- ✅ Network interface (ens18) configured

## Advanced: Custom Cloud-Init Config

If you want to customize, edit these sections in the script:

```bash
# Custom packages to install on first boot
qm set $VMID --ciuser k8sadmin
qm set $VMID --cipassword $(openssl rand -base64 12)
qm set $VMID --sshkeys ~/.ssh/k8s_cluster.pub
qm set $VMID --ipconfig0 ip=${IP}/24,gw=192.168.11.1
```

Or use full cloud-init YAML (snippets storage):
```yaml
#cloud-config
users:
  - name: k8sadmin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAA... your-key

packages:
  - qemu-guest-agent
  - vim
  - htop

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
```

## Troubleshooting

### VM doesn't get IP
```bash
# Check cloud-init status
ssh k8sadmin@192.168.11.201  # Use IP directly first
cloud-init status

# View logs
sudo cat /var/log/cloud-init.log
```

### SSH key not working
```bash
# Verify key was injected
qm cloudinit dump 201 user

# Check inside VM
cat ~/.ssh/authorized_keys
```

### Need to recreate VM
```bash
# Delete and recreate
qm stop 201
qm destroy 201
./00-create-vms-cloudinit.sh  # Run again
```

## Other Automation Methods

### Method 2: Packer + Terraform
- **Packer**: Build custom VM templates
- **Terraform**: Deploy VMs from templates
- Best for: Complex, multi-environment setups

### Method 3: Ansible
- Configure VMs after creation
- Best for: Configuration management

### Method 4: Proxmox Templates
- Create one VM manually
- Convert to template
- Clone for other VMs

## Why Cloud-Init is Best for This Project

1. **Speed**: 10x faster than manual
2. **Repeatability**: Same config every time
3. **Version Control**: Config is code (can commit to git)
4. **Industry Standard**: Used by AWS, Azure, GCP
5. **Learning**: Valuable skill for cloud platforms

## Files

- **Script**: `/root/claude/k8s-platform/scripts/00-create-vms-cloudinit.sh`
- **Manual Guide**: `/root/k8s-vm-installation-guide.txt` (backup method)

## Recommendation

Use **Cloud-Init method** (`00-create-vms-cloudinit.sh`) for:
- ✅ Faster setup
- ✅ Consistency
- ✅ Automation
- ✅ Easy to recreate VMs

Use **Manual method** only if:
- ❌ Cloud image download fails
- ❌ You want to learn the installation process
- ❌ Very specific custom requirements
