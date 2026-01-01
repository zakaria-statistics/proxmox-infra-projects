# cert-manager: Managed TLS Certificates

## What is cert-manager?

**A Kubernetes operator that automates certificate management.**

**What you did manually (native approach):**
1. Generate certificate with OpenSSL
2. Create Kubernetes Secret (type: tls)
3. Reference Secret in Ingress
4. Before expiry: Renew cert manually, update Secret

**What cert-manager automates:**
1. Generate certificate via ACME (Let's Encrypt)
2. Create Kubernetes Secret automatically
3. Ingress references Secret (same as manual)
4. Auto-renew before expiry (updates Secret)

---

## Architecture: Native vs Managed

### Native (Manual) - What We Practiced

```
You (human)
  ↓ (run openssl commands)
Certificate Files (tls.crt, tls.key)
  ↓ (kubectl create secret)
Secret (type: kubernetes.io/tls)
  ↓ (referenced by)
Ingress (spec.tls.secretName)
  ↓ (used by)
Ingress Controller (terminates TLS)
```

**Manual renewal:**
- Certificate expires in 365 days
- You must regenerate before expiry
- Update Secret with new cert
- May require pod restarts

### Managed (cert-manager)

```
Ingress (with annotation: cert-manager.io/cluster-issuer)
  ↓ (watched by)
cert-manager Controller
  ↓ (creates)
Certificate Resource (CRD)
  ↓ (triggers)
ACME Challenge (HTTP-01 or DNS-01)
  ↓ (validates with)
Let's Encrypt
  ↓ (issues)
Certificate Files
  ↓ (stored in)
Secret (type: kubernetes.io/tls) ← Same as manual!
  ↓ (used by)
Ingress Controller (terminates TLS)
```

**Auto-renewal:**
- Certificate expires in 90 days (Let's Encrypt)
- cert-manager renews at 60 days
- Secret updated automatically
- Ingress Controller picks up new cert (no restart)

---

## Native Resources Created by cert-manager

**What cert-manager adds:**

| Resource Type | Name | Purpose |
|--------------|------|---------|
| Namespace | cert-manager | Isolates cert-manager components |
| Deployment | cert-manager | Main controller |
| Deployment | cert-manager-webhook | Validates Certificate resources |
| Deployment | cert-manager-cainjector | Injects CA into webhooks |
| Service | cert-manager, cert-manager-webhook | Internal APIs |
| CRD | Certificate | Defines a certificate to issue |
| CRD | Issuer / ClusterIssuer | Defines how to get certs (Let's Encrypt config) |
| CRD | CertificateRequest | Internal: tracks cert issuance |
| CRD | Challenge | Internal: ACME challenges |
| CRD | Order | Internal: ACME orders |

**What cert-manager creates per Ingress:**

| Resource | Created By | Purpose |
|----------|-----------|---------|
| Certificate | cert-manager (watches Ingress) | Defines cert details |
| Secret (tls) | cert-manager (after ACME) | Stores cert/key (same as manual!) |

---

## Installation (For Reference - Don't Run Yet)

```bash
# Install cert-manager (using kubectl)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Or using Helm (managed package manager)
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Verify installation
kubectl get pods -n cert-manager
kubectl get crds | grep cert-manager
```

---

## Example: ClusterIssuer (Let's Encrypt)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # Let's Encrypt production server
    server: https://acme-v02.api.letsencrypt.org/directory

    # Email for expiry notifications
    email: your-email@example.com

    # Secret to store ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod

    # Challenge solver: HTTP-01 (serves file at /.well-known/acme-challenge/)
    solvers:
    - http01:
        ingress:
          class: nginx
```

**What this does:**
- Defines how to get certificates from Let's Encrypt
- Uses HTTP-01 challenge (Let's Encrypt checks your domain via HTTP)
- Saves ACME account key in a Secret

---

## Example: Ingress with cert-manager Annotation

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-app-ingress
  namespace: tls-demo
  annotations:
    # THIS IS THE KEY ANNOTATION:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure-app.example.com  # Real domain (not .local)
    secretName: secure-app-tls  # cert-manager will create this!
  rules:
  - host: secure-app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-app
            port:
              number: 80
```

**What happens:**

1. You apply this Ingress
2. cert-manager sees annotation: `cert-manager.io/cluster-issuer`
3. cert-manager creates a `Certificate` resource
4. cert-manager contacts Let's Encrypt (ACME protocol)
5. Let's Encrypt sends HTTP-01 challenge:
   - Requests: `http://secure-app.example.com/.well-known/acme-challenge/xyz`
6. cert-manager creates temporary Ingress to serve challenge file
7. Let's Encrypt validates domain ownership
8. Let's Encrypt issues certificate
9. cert-manager creates Secret: `secure-app-tls` (same name you specified!)
10. Ingress Controller uses Secret (same as manual approach)

---

## Comparison: Manual vs cert-manager

| Aspect | Manual (Native) | cert-manager (Managed) |
|--------|----------------|----------------------|
| **Certificate Creation** | openssl commands | ACME with Let's Encrypt |
| **Secret Creation** | kubectl create secret | Automatic |
| **Trust** | Self-signed (browser warnings) | CA-signed (trusted) |
| **Expiry** | 365 days (your choice) | 90 days (Let's Encrypt) |
| **Renewal** | Manual (run commands again) | Automatic (at 60 days) |
| **DNS Required** | No (local testing) | Yes (Let's Encrypt validates domain) |
| **Cost** | Free | Free (Let's Encrypt) |
| **Complexity** | Simple (3 commands) | Complex (install operator, CRDs) |

---

## When to Use Each Approach

### Use Manual (Native) When:
- ✅ Local development/testing
- ✅ Learning TLS concepts
- ✅ Internal-only applications (no public DNS)
- ✅ Custom CA requirements
- ✅ Air-gapped environments (no internet)

### Use cert-manager (Managed) When:
- ✅ Production public-facing apps
- ✅ Need trusted certificates (no browser warnings)
- ✅ Many certificates to manage
- ✅ Auto-renewal is critical
- ✅ Have public DNS control

---

## Challenge Types

### HTTP-01 Challenge (Simpler)
```yaml
solvers:
- http01:
    ingress:
      class: nginx
```

**How it works:**
1. Let's Encrypt asks: "Serve file X at `/.well-known/acme-challenge/X`"
2. cert-manager creates temporary Ingress rule
3. Let's Encrypt fetches file via HTTP
4. Validates you control the domain

**Requirements:**
- Port 80 must be accessible from internet
- Ingress Controller must be public

**Pros:** Simple, no DNS provider config
**Cons:** Requires port 80, can't issue wildcard certs

### DNS-01 Challenge (Advanced)
```yaml
solvers:
- dns01:
    cloudflare:
      apiTokenSecretRef:
        name: cloudflare-api-token
        key: api-token
```

**How it works:**
1. Let's Encrypt asks: "Create TXT record `_acme-challenge.example.com`"
2. cert-manager calls DNS provider API (Cloudflare, Route53, etc.)
3. Let's Encrypt checks DNS record
4. Validates you control the domain

**Requirements:**
- DNS provider with API support
- API credentials stored in Secret

**Pros:** Can issue wildcard certs (`*.example.com`), no port 80 needed
**Cons:** Requires DNS provider config, slower (DNS propagation)

---

## Hybrid Approach (Recommended Learning Path)

**You've completed:** Manual TLS with self-signed certificates ✅

**Next steps:**
1. **Understand what you learned:**
   - How Secrets store certificates
   - How Ingress references Secrets
   - How TLS termination works
   - Certificate expiry and renewal challenges

2. **When you need production certs:**
   - Install cert-manager
   - Create ClusterIssuer (Let's Encrypt)
   - Annotate existing Ingress
   - **Inspect the Secret cert-manager creates** (same structure as manual!)
   - Compare: cert-manager Secret vs manual Secret (identical!)

3. **Debugging cert-manager:**
   - Check Certificate resource: `kubectl get certificate -A`
   - Check CertificateRequest: `kubectl get certificaterequest -A`
   - Check Challenge: `kubectl get challenge -A`
   - Check cert-manager logs: `kubectl logs -n cert-manager deploy/cert-manager`
   - **Because you understand native Secrets**, you can debug cert-manager!

---

## Key Takeaway

**cert-manager creates the SAME native resources you created manually:**
- Secret (type: kubernetes.io/tls)
- Ingress references secretName

**You now understand:**
- What cert-manager automates (certificate generation, Secret creation, renewal)
- What native resources it creates (Secrets, same as manual)
- How to inspect those resources (kubectl get secret, describe, etc.)
- How to debug when it fails (check Secret, Certificate resource, logs)

**This is the power of learning native first!** 🎯

---

**Related Practice:**
- HPA practice: `k8s-platform/native-concepts/hpa-practice/`
- StatefulSets (coming next for Phase 3 - DB Cluster)
