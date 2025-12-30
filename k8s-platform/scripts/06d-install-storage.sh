#!/bin/bash
###############################################################################
# Script: 06d-install-storage.sh
# Purpose: Install local-path-provisioner for persistent storage
# Run Location: Control plane only (VM 201)
# Timeline: 5 minutes
###############################################################################

set -e

echo "======================================"
echo "Install Storage Provisioner"
echo "======================================"
echo

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}What is a Storage Provisioner?${NC}"
echo "  - Automatically creates persistent volumes for your applications"
echo "  - Without it: You manually create PersistentVolume for each request"
echo "  - With it: Just request storage, it's created automatically"
echo

echo -e "${BLUE}Why local-path-provisioner?${NC}"
echo "  ✓ Simple: Uses local disk on worker nodes"
echo "  ✓ No external dependencies (no NFS/Ceph needed)"
echo "  ✓ Perfect for homelab/development"
echo "  ✓ Good performance (local SSD/HDD)"
echo

echo -e "${BLUE}How it works:${NC}"
echo "  1. App creates PersistentVolumeClaim (PVC) requesting 10GB"
echo "  2. Provisioner creates directory on worker node: /opt/local-path-provisioner/"
echo "  3. Mounts directory into pod as volume"
echo "  4. Data persists even if pod is deleted/restarted"
echo

echo -e "${YELLOW}Note: Data is tied to specific node${NC}"
echo "  - If pod moves to different node, it won't see the same data"
echo "  - For distributed storage, consider Longhorn or NFS"
echo

echo -e "${YELLOW}Installing local-path-provisioner...${NC}"
echo

# ============================================================================
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

echo "✓ Storage provisioner installed"
echo

# ============================================================================
echo "Waiting for provisioner to be ready..."
echo

kubectl wait --for=condition=ready pod \
    -l app=local-path-provisioner \
    -n local-path-storage \
    --timeout=180s

echo
echo "✓ Storage provisioner is running"
echo

# ============================================================================
echo -e "${BLUE}Setting as default StorageClass${NC}"
echo

# Set as default storage class
kubectl patch storageclass local-path \
    -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo "✓ Set as default StorageClass"
echo

# ============================================================================
echo "======================================"
echo "Storage Provisioner Installed!"
echo "======================================"
echo

echo "Storage Classes:"
kubectl get storageclass

echo

echo "Example PersistentVolumeClaim:"
cat <<'EOF'

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  # storageClassName: local-path  # Optional, it's default

---
# Use in a Pod
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: my-app-data
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: data
          mountPath: /data

EOF

echo "Test storage:"
echo "  kubectl apply -f <above-yaml>"
echo "  kubectl exec -it my-app -- sh -c 'echo test > /data/file.txt'"
echo "  kubectl delete pod my-app"
echo "  kubectl apply -f <above-yaml>  # Recreate pod"
echo "  kubectl exec -it my-app -- cat /data/file.txt  # Data persists!"
echo

echo "Next Steps:"
echo "  → Install OpenFaaS (optional): ./06e-install-openfaas.sh"
echo "  → Verify cluster: ./07-verify-cluster.sh"
echo
