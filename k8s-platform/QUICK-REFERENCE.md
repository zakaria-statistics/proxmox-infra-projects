# Kubernetes Quick Reference

## Installation Order

```
Proxmox Host:
  01-create-vms.sh

All VMs (after OS install):
  02-prepare-os.sh
  03-install-kubernetes.sh

Control Plane Only:
  04-init-control-plane.sh
  06a-install-calico.sh
  05-get-join-command.sh

Workers (run join command from above)

Control Plane:
  06b-install-metallb.sh
  06c-install-ingress.sh
  06d-install-storage.sh
  06e-install-openfaas.sh (optional)
  07-verify-cluster.sh
  08-deploy-test-app.sh
```

## Network Info

| Resource | IP/CIDR |
|----------|---------|
| Control Plane | 192.168.11.201 |
| Worker 1 | 192.168.11.202 |
| Worker 2 | 192.168.11.203 |
| Pod Network | 10.244.0.0/16 |
| Service Network | 10.96.0.0/12 |
| MetalLB Pool | 192.168.11.240-250 |

## Essential Commands

### Cluster Info
```bash
kubectl cluster-info
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node <name>
```

### Pods
```bash
kubectl get pods
kubectl get pods -A              # All namespaces
kubectl get pods -o wide         # Show node placement
kubectl describe pod <name>
kubectl logs <name>
kubectl logs <name> -f           # Follow logs
kubectl logs <name> --previous   # Previous instance
kubectl exec -it <name> -- bash
kubectl delete pod <name>
```

### Deployments
```bash
kubectl get deployments
kubectl create deployment nginx --image=nginx
kubectl scale deployment nginx --replicas=5
kubectl set image deployment/nginx nginx=nginx:1.25
kubectl rollout status deployment/nginx
kubectl rollout undo deployment/nginx
kubectl delete deployment nginx
```

### Services
```bash
kubectl get svc
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl describe svc nginx
kubectl delete svc nginx
```

### Ingress
```bash
kubectl get ingress
kubectl describe ingress <name>
```

### Storage
```bash
kubectl get pv              # Persistent Volumes
kubectl get pvc             # Persistent Volume Claims
kubectl describe pvc <name>
```

### Namespaces
```bash
kubectl get namespaces
kubectl create namespace myapp
kubectl get pods -n myapp
kubectl delete namespace myapp
```

### Apply Manifests
```bash
kubectl apply -f deployment.yaml
kubectl apply -f .                    # All YAMLs in dir
kubectl delete -f deployment.yaml
```

### Debug
```bash
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -n kube-system
kubectl top nodes
kubectl top pods -A
```

## Common YAML Patterns

### Minimal Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
```

### LoadBalancer Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
  ports:
  - port: 80
  type: LoadBalancer
```

### Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
spec:
  ingressClassName: nginx
  rules:
  - host: app.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
```

### PVC
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

## Troubleshooting

### Pod Won't Start
```bash
kubectl describe pod <name>  # Check Events
kubectl logs <name>          # Check logs
```

### Service Not Accessible
```bash
kubectl get svc              # Check EXTERNAL-IP
kubectl get endpoints <svc>  # Check endpoints
```

### Node NotReady
```bash
kubectl describe node <name>
ssh <node>
journalctl -u kubelet -f
```

### Check System Pods
```bash
kubectl get pods -n kube-system
kubectl get pods -n metallb-system
kubectl get pods -n ingress-nginx
```

## File Locations

### Kubernetes Config
- `/etc/kubernetes/` - K8s configuration
- `/etc/kubernetes/manifests/` - Static pods
- `~/.kube/config` - kubectl config

### Logs
```bash
journalctl -u kubelet -f
journalctl -u containerd -f
```

### Certificates
- `/etc/kubernetes/pki/` - Cluster certificates

## Port Reference

| Service | Port |
|---------|------|
| API Server | 6443 |
| etcd | 2379-2380 |
| kubelet | 10250 |
| Ingress HTTP | 80 |
| Ingress HTTPS | 443 |
| OpenFaaS Gateway | 8080 |

## Resource Requests/Limits

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"      # 0.1 CPU
  limits:
    memory: "128Mi"
    cpu: "200m"      # 0.2 CPU
```

## Useful Aliases

```bash
# Add to ~/.bashrc
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
alias ka='kubectl apply -f'
alias kdel='kubectl delete'

source <(kubectl completion bash)
complete -F __start_kubectl k
```

## Emergency

### Drain Node (Maintenance)
```bash
kubectl drain <node> --ignore-daemonsets
# Do maintenance
kubectl uncordon <node>
```

### Delete Stuck Pod
```bash
kubectl delete pod <name> --force --grace-period=0
```

### Reset Node (Dangerous!)
```bash
kubeadm reset
rm -rf ~/.kube
```

### Backup etcd
```bash
ETCDCTL_API=3 etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```
