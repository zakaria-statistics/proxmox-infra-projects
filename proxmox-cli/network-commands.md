# Proxmox Network Commands - Copy & Paste Reference

## Network Status

### Show interfaces
```bash
ip addr show
ip link show
```

### Show bridges
```bash
brctl show
ip link show type bridge
```

### Show network configuration
```bash
cat /etc/network/interfaces
```

### Show routing table
```bash
ip route show
route -n
```

### Test connectivity
```bash
ping -c 3 8.8.8.8
ping -c 3 192.168.11.1
```

## Bridge Management

### Show bridge details
```bash
brctl show vmbr0
bridge link show dev vmbr0
```

### Show bridge MAC table
```bash
brctl showmacs vmbr0
```

## IP Configuration

### Add IP to bridge (temporary)
```bash
ip addr add 192.168.11.50/24 dev vmbr0
```

### Remove IP from bridge
```bash
ip addr del 192.168.11.50/24 dev vmbr0
```

### Change IP (edit config then reload)
```bash
nano /etc/network/interfaces
ifreload -a
```

## DNS Configuration

### Check DNS
```bash
cat /etc/resolv.conf
```

### Test DNS resolution
```bash
nslookup google.com
dig google.com
host google.com
```

### Change DNS (edit resolv.conf)
```bash
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
```

## Firewall

### Firewall status
```bash
pve-firewall status
```

### Enable/disable firewall
```bash
pve-firewall enable
pve-firewall disable
```

### View firewall rules
```bash
cat /etc/pve/firewall/cluster.fw
iptables -L -n -v
```

### Add firewall rule (edit cluster firewall)
```bash
nano /etc/pve/firewall/cluster.fw
```

Example rule:
```
[RULES]
IN ACCEPT -p tcp -dport 22 -source 192.168.11.0/24
IN ACCEPT -p tcp -dport 8006 -source 192.168.11.0/24
```

## Network Traffic Monitoring

### Show traffic by interface
```bash
ip -s link show
ifconfig
```

### Monitor traffic real-time
```bash
iftop -i vmbr0
iftop -i eth0
```

### Network statistics
```bash
netstat -i
netstat -an | grep ESTABLISHED | wc -l  # active connections
```

### Bandwidth usage
```bash
vnstat -i vmbr0
vnstat -l -i vmbr0  # live
```

## TCP/UDP Connections

### Show all connections
```bash
ss -tuln          # listening
ss -tun           # established
netstat -tuln
```

### Show connections to specific port
```bash
ss -tn sport = :22
ss -tn dport = :8006
```

### Count connections by state
```bash
ss -s
netstat -ant | awk '{print $6}' | sort | uniq -c
```

## Check Ports (Netcat)
```bash
# Check local Proxmox Web UI & SSH
nc -zv localhost 8006
nc -zv localhost 22
```


## ARP Table

### Show ARP cache
```bash
ip neigh show
arp -a
```

### Clear ARP cache
```bash
ip neigh flush all
```

## VLAN Configuration

### Create VLAN interface (temporary)
```bash
ip link add link eth0 name eth0.10 type vlan id 10
ip addr add 192.168.10.1/24 dev eth0.10
ip link set eth0.10 up
```

### Permanent VLAN (in /etc/network/interfaces)
```
auto vmbr0.10
iface vmbr0.10 inet static
    address 192.168.10.1/24
    vlan-raw-device vmbr0
```

## Port Forwarding

### Enable IP forwarding
```bash
# Temporary
echo 1 > /proc/sys/net/ipv4/ip_forward

# Permanent
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

### Simple NAT rule
```bash
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

### Port forward example
```bash
# Forward port 8080 to VM on 192.168.11.100:80
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to 192.168.11.100:80
iptables -A FORWARD -p tcp -d 192.168.11.100 --dport 80 -j ACCEPT
```

## Network Troubleshooting

### Check if port is open
```bash
nc -zv 192.168.11.100 22
telnet 192.168.11.100 22
```

### Trace route
```bash
traceroute 8.8.8.8
mtr 8.8.8.8       # continuous
```

### Packet capture
```bash
tcpdump -i vmbr0
tcpdump -i vmbr0 port 22
tcpdump -i vmbr0 host 192.168.11.100
```

### Check network latency
```bash
ping -c 10 192.168.11.1 | tail -1
```

## MAC Address Management

### Show MAC addresses
```bash
ip link show | grep link/ether
```

### Change MAC address (temporary)
```bash
ip link set dev eth0 down
ip link set dev eth0 address aa:bb:cc:dd:ee:ff
ip link set dev eth0 up
```

## Network Performance

### Measure bandwidth between hosts
```bash
# On server
iperf3 -s

# On client
iperf3 -c 192.168.11.100
```

### Check network interface speed
```bash
ethtool eth0 | grep Speed
```

## Get VM/Container IPs

### List all IPs
```bash
# VMs (requires guest agent)
qm list | tail -n +2 | while read vmid status name; do
  ip=$(qm agent $vmid network-get-interfaces 2>/dev/null | grep -oP '(?<="ip-address":")[^"]*' | grep -v "127.0.0.1" | head -1)
  echo "VM $vmid: $ip"
done

# Containers
for ct in $(pct list | tail -n +2 | awk '{print $1}'); do
  echo "CT $ct: $(pct config $ct | grep "net0" | grep -oP 'ip=\K[^,]+')"
done
```

### Find VM/container by IP
```bash
grep -r "192.168.11.100" /etc/pve/nodes/*/qemu-server/
grep -r "192.168.11.100" /etc/pve/nodes/*/lxc/
```
