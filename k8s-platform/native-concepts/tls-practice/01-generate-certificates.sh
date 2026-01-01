#!/bin/bash
###############################################################################
# Generate Self-Signed TLS Certificates
# Purpose: Create certificates for HTTPS testing in Kubernetes
###############################################################################

set -e

echo "======================================"
echo "Generate Self-Signed TLS Certificates"
echo "======================================"
echo

echo "What we're creating:"
echo "  - Private key (tls.key) - Keep this secret!"
echo "  - Certificate (tls.crt) - Public, shared with clients"
echo "  - Self-signed (not from a CA like Let's Encrypt)"
echo

echo "Certificate details:"
echo "  - Domain: secure-app.local"
echo "  - Validity: 365 days"
echo "  - Algorithm: RSA 2048-bit"
echo

# Domain name
DOMAIN="secure-app.local"
CERT_DIR="./certs"

# Create directory for certificates
mkdir -p "$CERT_DIR"

echo "Step 1: Generate private key..."
openssl genrsa -out "$CERT_DIR/tls.key" 2048

echo "✓ Private key created: $CERT_DIR/tls.key"
echo

echo "Step 2: Generate certificate signing request (CSR)..."
openssl req -new -key "$CERT_DIR/tls.key" -out "$CERT_DIR/tls.csr" \
  -subj "/CN=$DOMAIN/O=MyOrg/C=US"

echo "✓ CSR created: $CERT_DIR/tls.csr"
echo

echo "Step 3: Self-sign the certificate (valid 365 days)..."
openssl x509 -req -days 365 \
  -in "$CERT_DIR/tls.csr" \
  -signkey "$CERT_DIR/tls.key" \
  -out "$CERT_DIR/tls.crt"

echo "✓ Certificate created: $CERT_DIR/tls.crt"
echo

# Cleanup CSR (not needed anymore)
rm "$CERT_DIR/tls.csr"

echo "======================================"
echo "Certificates Generated!"
echo "======================================"
echo

echo "Files created in $CERT_DIR/:"
ls -lh "$CERT_DIR/"
echo

echo "Inspect certificate:"
echo "  openssl x509 -in $CERT_DIR/tls.crt -text -noout"
echo

echo "Certificate details:"
openssl x509 -in "$CERT_DIR/tls.crt" -noout -subject -issuer -dates
echo

echo "What each file contains:"
echo "  tls.key: Private key (2048-bit RSA)"
echo "    - Never share this!"
echo "    - Used by Ingress to decrypt TLS traffic"
echo "    - Stored in Kubernetes Secret"
echo
echo "  tls.crt: Public certificate"
echo "    - Shared with clients during TLS handshake"
echo "    - Contains public key and domain name"
echo "    - Stored in Kubernetes Secret"
echo

echo "Why self-signed?"
echo "  ✓ No external dependencies (no Let's Encrypt, no CA)"
echo "  ✓ Instant creation (no DNS validation)"
echo "  ✓ Perfect for local development/testing"
echo "  ✗ Browser warnings ('Not secure' - not trusted by browsers)"
echo "  ✗ Manual renewal (expires in 365 days)"
echo

echo "Production alternative:"
echo "  Use cert-manager with Let's Encrypt:"
echo "    - Free, trusted certificates"
echo "    - Auto-renewal every 90 days"
echo "    - No browser warnings"
echo "  See: 06-cert-manager-intro.md"
echo

echo "======================================"
echo "Next Step:"
echo "======================================"
echo "Create Kubernetes Secret from these certificates:"
echo "  kubectl create secret tls secure-app-tls \\"
echo "    --cert=$CERT_DIR/tls.crt \\"
echo "    --key=$CERT_DIR/tls.key \\"
echo "    -n tls-demo"
echo
echo "Or use the YAML:"
echo "  kubectl apply -f 02-create-tls-secret.yaml"
echo
