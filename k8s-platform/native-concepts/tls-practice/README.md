# TLS/HTTPS Practice in Kubernetes

## Learning Objectives

**Native Kubernetes concepts:** TLS termination, Secrets, Ingress with HTTPS

**What you'll learn:**
- How to generate TLS certificates (self-signed for testing)
- How to store certificates in Kubernetes Secrets
- How Ingress terminates TLS and serves HTTPS
- How to configure SNI (Server Name Indication) for multiple domains
- Certificate management challenges

**What this replaces in managed tools:**
- **cert-manager** (automates certificate creation & renewal)
- **Let's Encrypt integration** (free, auto-renewed certs)
- **External Secrets Operator** (syncs certs from external vaults)

---

## Architecture

```
Client (HTTPS request)
    ↓ (TLS handshake)
Ingress Controller (nginx)
    ↓ (terminates TLS using Secret)
    ↓ (forwards HTTP to backend)
Service (ClusterIP)
    ↓
Pods (application)
```

**Key point:** TLS is terminated at the Ingress. Backend communication is HTTP (unless you configure end-to-end TLS).

---

## Steps

1. **Generate certificates** - `./01-generate-certificates.sh`
2. **Create TLS Secret** - `kubectl apply -f 02-create-tls-secret.yaml`
3. **Deploy test app** - `kubectl apply -f 03-deploy-app.yaml`
4. **Configure Ingress with TLS** - `kubectl apply -f 04-ingress-with-tls.yaml`
5. **Test HTTPS** - `./05-test-https.sh`
6. **Learn about cert-manager** - `cat 06-cert-manager-intro.md`

---

## Native Resources Created

| Resource | Purpose |
|----------|---------|
| Secret (type: tls) | Stores certificate (tls.crt) and private key (tls.key) |
| Ingress | Configures TLS termination and routing |
| Deployment | Sample application |
| Service | Exposes application to Ingress |

---

## TLS Secret Structure

```yaml
apiVersion: v1
kind: Secret
type: kubernetes.io/tls  # Special type for TLS
metadata:
  name: my-tls-secret
data:
  tls.crt: <base64-encoded certificate>
  tls.key: <base64-encoded private key>
```

**Ingress references this:**
```yaml
spec:
  tls:
  - hosts:
    - example.com
    secretName: my-tls-secret  # References the Secret above
```

---

## Certificate Types

### 1. Self-Signed (Development/Testing)
- **Pro:** Free, instant, no external dependencies
- **Con:** Browser warnings ("Not secure"), manual trust required
- **Use case:** Local development, internal testing
- **What we'll create in this practice**

### 2. CA-Signed (Production)
- **Pro:** Trusted by browsers, no warnings
- **Con:** Costs money (or use Let's Encrypt for free)
- **Use case:** Production websites
- **Managed approach:** cert-manager + Let's Encrypt

### 3. Mutual TLS (mTLS)
- **Pro:** Client also presents certificate (two-way auth)
- **Con:** Complex setup, client cert distribution
- **Use case:** Service-to-service auth, API security
- **Advanced topic:** Service mesh (Istio/Linkerd)

---

## Comparison: Native vs Managed

### Native TLS (what we're practicing):

```bash
# Manual steps:
1. Generate certificate with OpenSSL (expires in 365 days)
2. Create Kubernetes Secret with cert/key
3. Configure Ingress to use Secret
4. Before expiry: Manually renew cert, update Secret
5. Pods using the Ingress need to be restarted (sometimes)

# Full control, but manual renewal
```

### cert-manager (managed - automates certificates):

```bash
# One-time setup:
1. Install cert-manager (operator)
2. Create Issuer/ClusterIssuer (Let's Encrypt config)
3. Annotate Ingress: cert-manager.io/cluster-issuer: "letsencrypt"

# Behind the scenes (same as native!):
- cert-manager generates certificate via Let's Encrypt
- Creates Secret (type: tls) automatically
- Ingress uses the Secret (same as native)
- Auto-renews before expiry (new Secret created)

# What it abstracts:
- Certificate generation (ACME protocol with Let's Encrypt)
- Secret creation
- Renewal automation
- Challenge solving (HTTP-01 or DNS-01)
```

**Learning native first means:** When cert-manager fails to issue a cert, you know how to manually create a Secret and debug!

---

## Common Issues & Debugging

### Browser shows "Not secure" (self-signed certs)
- Expected! Self-signed certs aren't trusted by browsers
- Click "Advanced" → "Proceed anyway" (testing only)
- Or: Add cert to browser's trusted CA store

### Ingress not serving HTTPS
```bash
# Check Secret exists:
kubectl get secret my-tls-secret -n tls-demo

# Check Secret has correct keys:
kubectl get secret my-tls-secret -n tls-demo -o yaml
# Should have: data.tls.crt and data.tls.key

# Check Ingress references correct Secret:
kubectl describe ingress -n tls-demo
# Look for: TLS: my-tls-secret terminates example.local

# Check Ingress controller logs:
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Certificate expired
```bash
# Check certificate expiry:
echo | openssl s_client -connect example.local:443 2>/dev/null | openssl x509 -noout -dates

# Shows:
# notBefore: Dec 31 00:00:00 2025 GMT
# notAfter: Dec 31 00:00:00 2026 GMT  ← Expiry date
```

---

## SNI (Server Name Indication)

**Multiple domains, one Ingress Controller:**

```yaml
spec:
  tls:
  - hosts:
    - app1.local
    secretName: app1-tls
  - hosts:
    - app2.local
    secretName: app2-tls
  rules:
  - host: app1.local
    http:
      paths: [...]
  - host: app2.local
    http:
      paths: [...]
```

**How it works:**
1. Client connects and sends hostname in TLS handshake (SNI)
2. Ingress Controller selects correct certificate based on hostname
3. TLS handshake completes with appropriate cert
4. HTTP request is routed based on Host header

---

**Ready to start? Run:** `./01-generate-certificates.sh`
