#!/bin/bash
###############################################################################
# Script: 07-verify-cluster.sh
# Purpose: Comprehensive cluster health check
# Run Location: Control plane only (VM 201)
# Timeline: 5 minutes
###############################################################################

echo "======================================"
echo "Kubernetes Cluster Verification"
echo "======================================"
echo

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

ISSUES=0

# ============================================================================
echo -e "${BLUE}1. Cluster Information${NC}"
echo

kubectl cluster-info

echo
echo "✓ Cluster is accessible"
echo

# ============================================================================
echo -e "${BLUE}2. Node Status${NC}"
echo

kubectl get nodes -o wide

echo

# Check if all nodes are Ready
NOT_READY=$(kubectl get nodes --no-headers | grep -v "Ready" | wc -l)
if [ $NOT_READY -eq 0 ]; then
    echo -e "${GREEN}✓ All nodes are Ready${NC}"
else
    echo -e "${RED}✗ Some nodes are not Ready${NC}"
    ISSUES=$((ISSUES + 1))
fi

echo

# ============================================================================
echo -e "${BLUE}3. System Pods Status${NC}"
echo

kubectl get pods -n kube-system

echo

# Check for failing pods
FAILING_PODS=$(kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" | wc -l)
if [ $FAILING_PODS -eq 0 ]; then
    echo -e "${GREEN}✓ All system pods are running${NC}"
else
    echo -e "${RED}✗ Some system pods are not running${NC}"
    ISSUES=$((ISSUES + 1))
fi

echo

# ============================================================================
echo -e "${BLUE}4. CoreDNS Health Check${NC}"
echo

# Test DNS resolution
kubectl run test-dns --image=busybox:1.28 --restart=Never -- sleep 3600 2>/dev/null || true

echo "Waiting for test pod..."
sleep 5

DNS_TEST=$(kubectl exec test-dns -- nslookup kubernetes.default 2>/dev/null | grep "Name:" || echo "FAILED")

kubectl delete pod test-dns --force --grace-period=0 2>/dev/null || true

if echo "$DNS_TEST" | grep -q "kubernetes"; then
    echo -e "${GREEN}✓ DNS is working correctly${NC}"
else
    echo -e "${RED}✗ DNS resolution failed${NC}"
    ISSUES=$((ISSUES + 1))
fi

echo

# ============================================================================
echo -e "${BLUE}5. Network Connectivity Test${NC}"
echo

# Create test deployment
kubectl create deployment test-web --image=nginx --replicas=2 2>/dev/null || true

echo "Waiting for pods to start..."
kubectl wait --for=condition=ready pod -l app=test-web --timeout=60s

# Get pod IPs
POD_IPS=$(kubectl get pods -l app=test-web -o jsonpath='{.items[*].status.podIP}')

echo "Test pod IPs: $POD_IPS"

# Test connectivity between pods
FIRST_POD=$(kubectl get pods -l app=test-web -o jsonpath='{.items[0].metadata.name}')
SECOND_IP=$(kubectl get pods -l app=test-web -o jsonpath='{.items[1].status.podIP}')

if kubectl exec $FIRST_POD -- wget -T 5 -q -O- http://$SECOND_IP > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Pod-to-pod networking works${NC}"
else
    echo -e "${RED}✗ Pod-to-pod networking failed${NC}"
    ISSUES=$((ISSUES + 1))
fi

# Cleanup
kubectl delete deployment test-web

echo

# ============================================================================
echo -e "${BLUE}6. Storage Provisioner Check${NC}"
echo

STORAGE_CLASS=$(kubectl get storageclass --no-headers | grep "(default)" | awk '{print $1}')

if [ -n "$STORAGE_CLASS" ]; then
    echo -e "${GREEN}✓ Default storage class: $STORAGE_CLASS${NC}"

    # Test storage provisioning
    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

    echo "Testing storage provisioning..."
    sleep 5

    PVC_STATUS=$(kubectl get pvc test-pvc -o jsonpath='{.status.phase}')

    if [ "$PVC_STATUS" == "Bound" ]; then
        echo -e "${GREEN}✓ Storage provisioning works${NC}"
    else
        echo -e "${YELLOW}⚠ Storage provisioning may have issues (Status: $PVC_STATUS)${NC}"
    fi

    kubectl delete pvc test-pvc
else
    echo -e "${YELLOW}⚠ No default storage class found${NC}"
fi

echo

# ============================================================================
echo -e "${BLUE}7. MetalLB Load Balancer Check${NC}"
echo

METALLB_PODS=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null | wc -l)

if [ $METALLB_PODS -gt 0 ]; then
    echo -e "${GREEN}✓ MetalLB is installed${NC}"
    kubectl get ipaddresspool -n metallb-system
else
    echo -e "${YELLOW}⚠ MetalLB not found (optional)${NC}"
fi

echo

# ============================================================================
echo -e "${BLUE}8. Ingress Controller Check${NC}"
echo

INGRESS_PODS=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | wc -l)

if [ $INGRESS_PODS -gt 0 ]; then
    echo -e "${GREEN}✓ Ingress NGINX is installed${NC}"
    INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$INGRESS_IP" ]; then
        echo "  External IP: $INGRESS_IP"
    fi
else
    echo -e "${YELLOW}⚠ Ingress controller not found (optional)${NC}"
fi

echo

# ============================================================================
echo -e "${BLUE}9. Resource Usage${NC}"
echo

echo "Node Resources:"
kubectl top nodes 2>/dev/null || echo "Metrics server not installed (optional)"

echo

# ============================================================================
echo "======================================"
echo "Verification Summary"
echo "======================================"
echo

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo
    echo "Your Kubernetes cluster is healthy and ready to use."
else
    echo -e "${RED}✗ Found $ISSUES issue(s)${NC}"
    echo
    echo "Please review the failed checks above."
    echo "Check pod logs for more details:"
    echo "  kubectl logs -n kube-system <pod-name>"
fi

echo

echo "Cluster Summary:"
echo "  Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "  Namespaces: $(kubectl get ns --no-headers | wc -l)"
echo "  Running Pods: $(kubectl get pods --all-namespaces --no-headers | grep Running | wc -l)"
echo

echo "Next Steps:"
echo "  → Deploy test application: ./08-deploy-test-app.sh"
echo "  → View cluster resources: kubectl get all --all-namespaces"
echo "  → Monitor cluster: kubectl top nodes"
echo
