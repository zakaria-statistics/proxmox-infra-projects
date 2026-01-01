#!/bin/bash
###############################################################################
# Test HTTPS Configuration
# Purpose: Verify TLS termination is working
###############################################################################

echo "======================================"
echo "Test HTTPS/TLS Configuration"
echo "======================================"
echo

DOMAIN="secure-app.local"
INGRESS_IP="192.168.11.240"  # Your Ingress Controller LoadBalancer IP

echo "Prerequisites:"
echo "  1. Ingress Controller running (nginx)"
echo "  2. TLS Secret created (secure-app-tls)"
echo "  3. Application deployed (secure-app)"
echo "  4. Ingress configured (secure-app-ingress)"
echo "  5. /etc/hosts entry: $INGRESS_IP $DOMAIN"
echo

# Check /etc/hosts
echo "Checking /etc/hosts configuration..."
if grep -q "$DOMAIN" /etc/hosts; then
    echo "✓ /etc/hosts entry exists for $DOMAIN"
else
    echo "⚠ /etc/hosts entry missing!"
    echo "  Add this line to /etc/hosts:"
    echo "    echo '$INGRESS_IP $DOMAIN' | sudo tee -a /etc/hosts"
    echo
    read -p "Add it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$INGRESS_IP $DOMAIN" | sudo tee -a /etc/hosts
        echo "✓ Added to /etc/hosts"
    else
        echo "Skipping... Tests may fail without /etc/hosts entry"
    fi
fi
echo

# Test 1: Check Ingress exists
echo "Test 1: Check Ingress resource..."
if kubectl get ingress secure-app-ingress -n tls-demo &>/dev/null; then
    echo "✓ Ingress resource exists"
    kubectl get ingress secure-app-ingress -n tls-demo
else
    echo "✗ Ingress not found. Run: kubectl apply -f 04-ingress-with-tls.yaml"
    exit 1
fi
echo

# Test 2: Check Secret exists
echo "Test 2: Check TLS Secret..."
if kubectl get secret secure-app-tls -n tls-demo &>/dev/null; then
    echo "✓ TLS Secret exists"
    kubectl get secret secure-app-tls -n tls-demo
else
    echo "✗ Secret not found. Run: ./01-generate-certificates.sh"
    exit 1
fi
echo

# Test 3: HTTP redirect to HTTPS (should get 308)
echo "Test 3: HTTP → HTTPS redirect..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L http://$DOMAIN)
if [ "$HTTP_STATUS" == "200" ]; then
    echo "✓ HTTP redirects to HTTPS (status: $HTTP_STATUS)"
else
    echo "⚠ Unexpected status: $HTTP_STATUS"
fi
echo

# Test 4: HTTPS connection (with self-signed cert, use -k to ignore warnings)
echo "Test 4: HTTPS connection test..."
echo "  Testing: https://$DOMAIN"
echo

# Test with curl (ignore cert verification for self-signed)
if curl -k -s https://$DOMAIN | grep -q "HTTPS is Working"; then
    echo "✓ HTTPS connection successful!"
    echo
    echo "Response preview:"
    curl -k -s https://$DOMAIN | grep -A 2 "HTTPS is Working"
else
    echo "✗ HTTPS connection failed"
    echo
    echo "Debugging steps:"
    echo "  1. Check Ingress Controller logs:"
    echo "     kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50"
    echo
    echo "  2. Check if Ingress has TLS configured:"
    echo "     kubectl describe ingress secure-app-ingress -n tls-demo"
    echo
    echo "  3. Test with verbose curl:"
    echo "     curl -kv https://$DOMAIN"
fi
echo

# Test 5: Certificate details
echo "Test 5: Inspect certificate details..."
echo "  Certificate subject and issuer:"
echo

echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | \
    openssl x509 -noout -subject -issuer -dates 2>/dev/null || \
    echo "⚠ Could not retrieve certificate (connection may have failed)"

echo

# Test 6: Full TLS handshake details
echo "Test 6: TLS handshake details..."
echo "  (This will show the certificate chain and cipher used)"
echo

echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>&1 | \
    grep -E '(subject|issuer|Protocol|Cipher)' | head -10

echo

echo "======================================"
echo "Testing Complete!"
echo "======================================"
echo

echo "Access the application:"
echo "  Browser: https://$DOMAIN"
echo "    - You'll see a browser warning (self-signed certificate)"
echo "    - Click 'Advanced' → 'Proceed' to continue"
echo
echo "  curl: curl -k https://$DOMAIN"
echo "    - Flag -k ignores certificate verification"
echo
echo "  wget: wget --no-check-certificate https://$DOMAIN"
echo

echo "Why browser warnings?"
echo "  Self-signed certificates aren't trusted by browsers"
echo "  In production, use cert-manager with Let's Encrypt for trusted certs"
echo "  See: 06-cert-manager-intro.md"
echo

echo "Inspect native resources:"
echo "  kubectl get ingress,secret,svc,pods -n tls-demo"
echo "  kubectl describe ingress secure-app-ingress -n tls-demo"
echo

echo "View Ingress Controller logs:"
echo "  kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100"
echo
