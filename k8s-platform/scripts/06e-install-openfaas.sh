#!/bin/bash
###############################################################################
# Script: 06e-install-openfaas.sh
# Purpose: Install OpenFaaS serverless platform (OPTIONAL)
# Run Location: Control plane only (VM 201)
# Timeline: 15-20 minutes
###############################################################################

set -e

echo "======================================"
echo "Install OpenFaaS (Serverless Platform)"
echo "======================================"
echo

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}What is OpenFaaS?${NC}"
echo "  - Function-as-a-Service platform for Kubernetes"
echo "  - Write functions in any language (Python, Go, Node.js, etc.)"
echo "  - Auto-scaling based on load (0 to N replicas)"
echo "  - Pay-per-invocation model (saves resources)"
echo

echo -e "${BLUE}Use Cases:${NC}"
echo "  ✓ API endpoints: Lightweight microservices"
echo "  ✓ Scheduled tasks: Cron jobs (database backups, reports)"
echo "  ✓ Event processing: React to webhooks, messages"
echo "  ✓ ML inference: Serve AI models without always-on containers"
echo "  ✓ ETL pipelines: Data transformation jobs"
echo

echo -e "${BLUE}Example Workflow:${NC}"
echo "  1. Write Python function: def handle(req): return process(req)"
echo "  2. Deploy: faas-cli deploy"
echo "  3. Invoke: curl http://gateway:8080/function/my-func"
echo "  4. OpenFaaS auto-scales based on requests"
echo

echo -e "${YELLOW}This is OPTIONAL - skip if you don't need serverless${NC}"
read -p "Install OpenFaaS? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipping OpenFaaS installation"
    exit 0
fi

# ============================================================================
echo -e "${BLUE}Step 1: Install arkade (Package Manager)${NC}"
echo "  arkade simplifies installing Kubernetes apps"
echo

curl -sLS https://get.arkade.dev | sh

# Move arkade to PATH
sudo mv arkade /usr/local/bin/

echo "✓ arkade installed"
echo

# ============================================================================
echo -e "${BLUE}Step 2: Install OpenFaaS${NC}"
echo "  This deploys:"
echo "    - Gateway: API for deploying/invoking functions"
echo "    - Prometheus: Metrics for auto-scaling"
echo "    - NATS: Message queue for async invocations"
echo

arkade install openfaas

echo "✓ OpenFaaS installed"
echo

# ============================================================================
echo "Waiting for OpenFaaS pods to be ready..."
echo "(This may take 2-3 minutes)"
echo

kubectl rollout status -n openfaas deploy/gateway

echo
echo "✓ OpenFaaS is running"
echo

# ============================================================================
echo -e "${BLUE}Step 3: Get Gateway Credentials${NC}"
echo

# Get password
PASSWORD=$(kubectl get secret -n openfaas basic-auth -o jsonpath="{.data.basic-auth-password}" | base64 --decode)

# Get gateway URL (LoadBalancer IP)
GATEWAY_IP=$(kubectl get svc -n openfaas gateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# If no LoadBalancer IP, use NodePort
if [ -z "$GATEWAY_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    NODE_PORT=$(kubectl get svc -n openfaas gateway-external -o jsonpath='{.spec.ports[0].nodePort}')
    GATEWAY_URL="http://$NODE_IP:$NODE_PORT"
else
    GATEWAY_URL="http://$GATEWAY_IP:8080"
fi

echo
echo "======================================"
echo "OpenFaaS Installed Successfully!"
echo "======================================"
echo

echo -e "${GREEN}Gateway URL: $GATEWAY_URL${NC}"
echo -e "${GREEN}Username: admin${NC}"
echo -e "${GREEN}Password: $PASSWORD${NC}"
echo

echo "Save these credentials securely!"
echo

# ============================================================================
echo -e "${BLUE}Step 4: Install faas-cli (Function CLI)${NC}"
echo

curl -sSL https://cli.openfaas.com | sh
sudo mv faas-cli /usr/local/bin/

echo "✓ faas-cli installed"
echo

# ============================================================================
echo "Example: Deploy a Function"
echo

cat <<EOF
# 1. Login to gateway
faas-cli login \\
  --username admin \\
  --password $PASSWORD \\
  --gateway $GATEWAY_URL

# 2. Deploy a pre-built function
faas-cli deploy \\
  --image=functions/nodeinfo \\
  --name=nodeinfo \\
  --gateway=$GATEWAY_URL

# 3. Invoke the function
curl $GATEWAY_URL/function/nodeinfo

# 4. View function metrics
faas-cli list --gateway=$GATEWAY_URL

# 5. Scale function
faas-cli scale nodeinfo --replicas=3 --gateway=$GATEWAY_URL

EOF

echo

echo "Create Your Own Function:"
cat <<'EOF'

# 1. Create new function
faas-cli new --lang python3 my-function

# 2. Edit my-function/handler.py
cat > my-function/handler.py <<'HANDLER'
def handle(req):
    """Handle a request"""
    name = req if req else "World"
    return f"Hello, {name}!"
HANDLER

# 3. Build and deploy
faas-cli build -f my-function.yml
faas-cli push -f my-function.yml
faas-cli deploy -f my-function.yml

# 4. Test
curl $GATEWAY_URL/function/my-function -d "John"

EOF

echo

echo "Next Steps:"
echo "  → Access UI: $GATEWAY_URL/ui"
echo "  → Verify cluster: ./07-verify-cluster.sh"
echo
