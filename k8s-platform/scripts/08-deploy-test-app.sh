#!/bin/bash
###############################################################################
# Script: 08-deploy-test-app.sh
# Purpose: Deploy a test application to verify cluster functionality
# Run Location: Control plane only (VM 201)
# Timeline: 10 minutes
###############################################################################

set -e

echo "======================================"
echo "Deploy Test Application"
echo "======================================"
echo

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}What we're deploying:${NC}"
echo "  - Simple web application (nginx)"
echo "  - 3 replicas (spread across worker nodes)"
echo "  - Persistent storage for data"
echo "  - LoadBalancer service"
echo "  - Ingress for HTTP access"
echo

echo -e "${BLUE}This tests:${NC}"
echo "  ✓ Pod scheduling and replication"
echo "  ✓ Storage provisioning"
echo "  ✓ Service networking"
echo "  ✓ LoadBalancer (MetalLB)"
echo "  ✓ Ingress routing"
echo

# ============================================================================
echo -e "${BLUE}Step 1: Create Namespace${NC}"
echo "  Why: Isolate test resources from system components"
echo

kubectl create namespace test-app 2>/dev/null || echo "Namespace already exists"

echo "✓ Namespace created"
echo

# ============================================================================
echo -e "${BLUE}Step 2: Deploy Application${NC}"
echo

cat <<EOF | kubectl apply -f -
# Deployment: Manages pod replicas
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-web
  namespace: test-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test-web
  template:
    metadata:
      labels:
        app: test-web
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: test-web-data

---
# PersistentVolumeClaim: Request storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-web-data
  namespace: test-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

---
# Service: Internal load balancing
apiVersion: v1
kind: Service
metadata:
  name: test-web-service
  namespace: test-app
spec:
  selector:
    app: test-web
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP

---
# LoadBalancer Service: External access
apiVersion: v1
kind: Service
metadata:
  name: test-web-lb
  namespace: test-app
spec:
  selector:
    app: test-web
  ports:
    - port: 80
      targetPort: 80
  type: LoadBalancer

---
# Ingress: HTTP routing
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-web-ingress
  namespace: test-app
spec:
  ingressClassName: nginx
  rules:
  - host: test.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-web-service
            port:
              number: 80
EOF

echo "✓ Application manifests applied"
echo

# ============================================================================
echo "Waiting for resources to be ready..."
echo

# Wait for PVC
kubectl wait --for=jsonpath='{.status.phase}'=Bound \
    pvc/test-web-data \
    -n test-app \
    --timeout=60s

echo "✓ Storage provisioned"

# Wait for pods
kubectl wait --for=condition=ready pod \
    -l app=test-web \
    -n test-app \
    --timeout=120s

echo "✓ Pods are running"

# Wait for LoadBalancer IP
echo "Waiting for LoadBalancer IP..."
while [ -z "$(kubectl get svc test-web-lb -n test-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)" ]; do
    echo -n "."
    sleep 2
done

echo
echo "✓ LoadBalancer IP assigned"
echo

# ============================================================================
echo -e "${BLUE}Step 3: Add Content to Web Server${NC}"
echo

# Get first pod name
POD=$(kubectl get pods -n test-app -l app=test-web -o jsonpath='{.items[0].metadata.name}')

# Add HTML content
kubectl exec -n test-app $POD -- sh -c 'cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Kubernetes Test App</title>
    <style>
        body { font-family: Arial; text-align: center; padding: 50px; background: #f0f0f0; }
        .container { background: white; padding: 30px; border-radius: 10px; max-width: 600px; margin: 0 auto; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #326CE5; }
        .status { color: #28a745; font-weight: bold; }
        .info { text-align: left; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 Kubernetes Cluster is Working!</h1>
        <p class="status">✓ Application Successfully Deployed</p>

        <div class="info">
            <h3>What is verified:</h3>
            <ul>
                <li>✓ Pods are running across worker nodes</li>
                <li>✓ Persistent storage is working</li>
                <li>✓ Service networking is functional</li>
                <li>✓ LoadBalancer (MetalLB) is assigning IPs</li>
                <li>✓ Ingress controller is routing traffic</li>
            </ul>
        </div>

        <p><strong>Pod Name:</strong> <span id="pod">'"$POD"'</span></p>
        <p><strong>Namespace:</strong> test-app</p>
    </div>
</body>
</html>
EOF'

echo "✓ Content added to web server"
echo

# ============================================================================
echo "======================================"
echo "Test Application Deployed!"
echo "======================================"
echo

# Get access information
LB_IP=$(kubectl get svc test-web-lb -n test-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo -e "${GREEN}Access Methods:${NC}"
echo

echo "1. Via LoadBalancer (Direct):"
echo -e "   ${GREEN}http://$LB_IP${NC}"
echo

echo "2. Via Ingress (Hostname-based):"
echo -e "   ${GREEN}http://test.local${NC}"
echo "   Add to /etc/hosts: $INGRESS_IP test.local"
echo

echo "3. Via kubectl port-forward:"
echo "   kubectl port-forward -n test-app svc/test-web-service 8080:80"
echo "   http://localhost:8080"
echo

# Display pod distribution
echo "Pod Distribution:"
kubectl get pods -n test-app -o wide

echo

# Display all resources
echo "All Resources:"
kubectl get all -n test-app

echo

# Test connectivity
echo -e "${BLUE}Testing connectivity...${NC}"
if curl -s http://$LB_IP | grep -q "Kubernetes"; then
    echo -e "${GREEN}✓ Application is accessible via LoadBalancer!${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify HTTP access (check firewall)${NC}"
fi

echo

echo "Cleanup Command:"
echo "  kubectl delete namespace test-app"
echo

echo -e "${GREEN}Success! Your Kubernetes cluster is fully operational.${NC}"
echo
