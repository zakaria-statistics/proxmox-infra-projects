#!/bin/bash
###############################################################################
# Script: 06c-install-ingress.sh
# Purpose: Install NGINX Ingress Controller
# Run Location: Control plane only (VM 201)
# Timeline: 10 minutes
###############################################################################

set -e

echo "======================================"
echo "Install NGINX Ingress Controller"
echo "======================================"
echo

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}What is Ingress?${NC}"
echo "  - HTTP/HTTPS routing to services based on hostnames and paths"
echo "  - Single external IP for multiple services"
echo "  - SSL/TLS termination (HTTPS handling)"
echo "  - Path-based routing (example.com/api → api-svc, /web → web-svc)"
echo

echo -e "${BLUE}Example Use Case:${NC}"
echo "  Without Ingress (needs 3 LoadBalancer IPs):"
echo "    - blog.example.com → LoadBalancer IP 1 → blog service"
echo "    - api.example.com → LoadBalancer IP 2 → api service"
echo "    - app.example.com → LoadBalancer IP 3 → app service"
echo
echo "  With Ingress (needs 1 LoadBalancer IP):"
echo "    - blog.example.com → Ingress IP → routes to blog service"
echo "    - api.example.com → Same Ingress IP → routes to api service"
echo "    - app.example.com → Same Ingress IP → routes to app service"
echo

echo -e "${BLUE}Architecture:${NC}"
echo "  Internet/LAN → Ingress Controller (gets IP from MetalLB)"
echo "              ↓"
echo "  Ingress Controller reads Ingress resources"
echo "              ↓"
echo "  Routes traffic to appropriate Services → Pods"
echo

echo -e "${YELLOW}Installing NGINX Ingress Controller...${NC}"
echo

# ============================================================================
echo -e "${BLUE}Step 1: Deploy Ingress Controller${NC}"
echo

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

echo "✓ Ingress controller manifest applied"
echo

# ============================================================================
echo "Waiting for Ingress controller to start..."
echo "(This may take 2-3 minutes)"
echo

kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s

echo
echo "✓ Ingress controller is running"
echo

# ============================================================================
echo "Waiting for LoadBalancer IP assignment..."
echo

# Wait for external IP
while [ -z "$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)" ]; do
    echo -n "."
    sleep 2
done

INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo
echo "✓ LoadBalancer IP assigned: $INGRESS_IP"
echo

# ============================================================================
echo "======================================"
echo "NGINX Ingress Controller Installed!"
echo "======================================"
echo

echo "Ingress Controller Service:"
kubectl get svc -n ingress-nginx ingress-nginx-controller

echo

echo -e "${GREEN}Ingress IP: $INGRESS_IP${NC}"
echo

echo "Example Ingress Resource:"
cat <<'EOF'

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-service
            port:
              number: 80

EOF

echo "To use this Ingress:"
echo "  1. Save the above YAML to ingress.yaml"
echo "  2. kubectl apply -f ingress.yaml"
echo "  3. Add to /etc/hosts: $INGRESS_IP myapp.local"
echo "  4. Visit http://myapp.local"
echo

echo "Test Ingress with sample app:"
echo "  ./08-deploy-test-app.sh"
echo

echo "Next Steps:"
echo "  → Install Storage: ./06d-install-storage.sh"
echo "  → Install OpenFaaS (optional): ./06e-install-openfaas.sh"
echo
