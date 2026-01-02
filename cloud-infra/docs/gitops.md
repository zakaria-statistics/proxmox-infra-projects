# GitOps Concepts

**IMPORTANT:** Master native kubectl first before adopting GitOps tools.

## What is GitOps?

**GitOps = Git + Operations**

Your infrastructure and applications are defined in Git. Automated systems ensure your clusters match what's in Git.

### Traditional Deployment (Imperative)

```bash
# Developer manually runs commands
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl set image deployment/myapp myapp=v2

# Problems:
# - Who deployed what?
# - What's the current state?
# - How to rollback?
# - Drift between environments
```

### GitOps Deployment (Declarative)

```bash
# Developer commits to Git
git add k8s/deployment.yaml
git commit -m "Update myapp to v2"
git push

# GitOps controller (ArgoCD/Flux) automatically:
# 1. Detects Git change
# 2. Applies to cluster
# 3. Monitors for drift
# 4. Logs all changes

# Benefits:
# - Git is source of truth
# - Audit trail (who, what, when)
# - Easy rollback (git revert)
# - Consistent across environments
```

---

## GitOps Principles

1. **Declarative:** Everything defined as code (YAML, not commands)
2. **Versioned:** Git is single source of truth
3. **Automatically Applied:** Controller syncs Git → Cluster
4. **Continuously Reconciled:** Drift detection and auto-healing

---

## Why Learn Native kubectl First?

### Understand What GitOps Abstracts

**Native kubectl (what you should learn first):**
```bash
# Create deployment
kubectl apply -f deployment.yaml

# Update deployment
kubectl set image deployment/myapp myapp=v2

# Check status
kubectl get deployments
kubectl describe deployment myapp

# Rollback
kubectl rollout undo deployment/myapp

# Debug
kubectl logs deployment/myapp
kubectl get events
```

**GitOps (what happens automatically later):**
```yaml
# You only commit to Git
git commit -m "Update to v2"
git push

# ArgoCD/Flux handles:
# - kubectl apply
# - kubectl set image
# - kubectl rollout status
# - drift detection
# - auto-sync
```

**If you don't know native kubectl:**
- Can't debug GitOps when it fails
- Don't understand what ArgoCD/Flux are doing
- Can't manually intervene in emergencies
- Miss the fundamentals

---

## GitOps Tools

### ArgoCD (Recommended for Learning)

**Pros:**
- Beautiful UI (visual learning)
- Easy to see what's happening
- Manual sync or auto-sync
- Multi-cluster support

**Cons:**
- Additional component to manage
- Learning curve for app definitions

### Flux (Alternative)

**Pros:**
- Lightweight (no UI)
- Native Kubernetes CRDs
- GitOps Toolkit (modular)

**Cons:**
- CLI-only (less visual)
- Steeper learning curve

---

## Native kubectl Workflow (Learn This First)

### Phase 1: Manual Deployment (You Are Here)

**Goal:** Understand Kubernetes primitives

```bash
# 1. Create deployment
cat > deployment.yaml <<EOF
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
      - name: myapp
        image: nginx:1.21
        ports:
        - containerPort: 80
EOF

kubectl apply -f deployment.yaml

# 2. Verify
kubectl get deployments
kubectl get pods
kubectl describe deployment myapp

# 3. Update image
kubectl set image deployment/myapp myapp=nginx:1.22

# 4. Watch rollout
kubectl rollout status deployment/myapp

# 5. Check history
kubectl rollout history deployment/myapp

# 6. Rollback if needed
kubectl rollout undo deployment/myapp

# 7. Scale
kubectl scale deployment/myapp --replicas=5

# 8. View logs
kubectl logs deployment/myapp
```

**Practice this for:**
- Deployments
- Services (ClusterIP, LoadBalancer)
- ConfigMaps and Secrets
- Ingress
- StatefulSets
- Jobs and CronJobs
- HPA (Horizontal Pod Autoscaler)

**When you're comfortable (can deploy/debug/rollback without looking up commands), move to Phase 2.**

---

### Phase 2: Git-Based Manual Deployment

**Goal:** Version control your manifests

```bash
# 1. Create Git repo
mkdir myapp-k8s
cd myapp-k8s
git init

# 2. Organize manifests
mkdir -p k8s/{base,overlays/{dev,prod}}

# k8s/base/deployment.yaml
cat > k8s/base/deployment.yaml <<EOF
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
      - name: myapp
        image: myapp:latest
        ports:
        - containerPort: 8080
EOF

# k8s/base/service.yaml
cat > k8s/base/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: myapp
EOF

# 3. Commit to Git
git add k8s/
git commit -m "Initial Kubernetes manifests"
git remote add origin https://github.com/myorg/myapp-k8s.git
git push -u origin main

# 4. Deploy manually (still using kubectl, but from Git)
git clone https://github.com/myorg/myapp-k8s.git
cd myapp-k8s
kubectl apply -f k8s/base/

# 5. Update application
# Edit k8s/base/deployment.yaml (change image tag)
git commit -am "Update to v2"
git push

# Pull and apply manually
git pull
kubectl apply -f k8s/base/

# 6. Rollback
git revert HEAD
git push
kubectl apply -f k8s/base/
```

**Practice this until:**
- You're comfortable with Git-based workflows
- You understand how Git = source of truth
- You can rollback via Git
- You see the value but also the manual overhead

**Then move to Phase 3 (GitOps automation).**

---

### Phase 3: GitOps Automation (After Mastering Phases 1 & 2)

**Goal:** Automate Git → Cluster sync

#### Installing ArgoCD

```bash
# 1. Create namespace
kubectl create namespace argocd

# 2. Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Expose UI (via LoadBalancer)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# 4. Get external IP
kubectl get svc argocd-server -n argocd

# 5. Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 6. Login via UI
# URL: http://<EXTERNAL-IP>
# Username: admin
# Password: <from step 5>

# 7. Install ArgoCD CLI (optional)
brew install argocd  # macOS
# OR
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
```

#### Creating Your First GitOps Application

**Option 1: Via UI (Visual Learning)**

1. Open ArgoCD UI
2. Click "+ NEW APP"
3. Fill in:
   - Application Name: `myapp`
   - Project: `default`
   - Sync Policy: `Manual` (learn first, auto later)
   - Repository URL: `https://github.com/myorg/myapp-k8s`
   - Path: `k8s/base`
   - Cluster: `https://kubernetes.default.svc` (in-cluster)
   - Namespace: `default`
4. Click "CREATE"
5. Click "SYNC" to deploy
6. Watch it apply your manifests

**Option 2: Via CLI**

```bash
argocd app create myapp \
  --repo https://github.com/myorg/myapp-k8s \
  --path k8s/base \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy manual  # Start with manual sync

# View app
argocd app list

# Sync app (deploy)
argocd app sync myapp

# Watch status
argocd app wait myapp
```

**Option 3: Via Kubernetes CRD (Declarative)**

```yaml
# argocd-apps/myapp.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myapp-k8s
    targetRevision: main
    path: k8s/base
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:  # Auto-sync enabled
      prune: true     # Delete resources not in Git
      selfHeal: true  # Auto-correct drift
    syncOptions:
    - CreateNamespace=true
```

```bash
kubectl apply -f argocd-apps/myapp.yaml
```

#### GitOps Workflow

**Before (Manual kubectl):**
```bash
# Developer workflow
1. Edit deployment.yaml locally
2. kubectl apply -f deployment.yaml
3. Hope it worked
4. No audit trail
```

**After (GitOps with ArgoCD):**
```bash
# Developer workflow
1. Edit k8s/base/deployment.yaml in Git repo
2. git commit -m "Update image to v2"
3. git push

# ArgoCD automatically (if auto-sync enabled):
4. Detects Git change
5. Applies to cluster
6. Shows sync status in UI
7. Logs who made the change
8. Can auto-rollback on failure

# To rollback:
git revert HEAD
git push
# ArgoCD auto-syncs the rollback
```

---

## Multi-Cluster GitOps

### Native kubectl (Multi-Cluster Manual)

```bash
# Switch context
kubectl config use-context aks-cluster-01
kubectl apply -f k8s/

kubectl config use-context eks-cluster-01
kubectl apply -f k8s/

kubectl config use-context gke-cluster-01
kubectl apply -f k8s/

# Problems:
# - Manual switching
# - Easy to deploy to wrong cluster
# - No unified view
```

### GitOps (Multi-Cluster Automated)

**Directory Structure:**
```
myapp-gitops/
├── apps/
│   └── myapp/
│       ├── base/              # Shared manifests
│       │   ├── deployment.yaml
│       │   └── service.yaml
│       └── overlays/
│           ├── aks-prod/      # AKS-specific
│           │   └── kustomization.yaml
│           ├── eks-prod/      # EKS-specific
│           │   └── kustomization.yaml
│           └── gke-prod/      # GKE-specific
│               └── kustomization.yaml
└── clusters/
    ├── aks-cluster-01.yaml    # ArgoCD App for AKS
    ├── eks-cluster-01.yaml    # ArgoCD App for EKS
    └── gke-cluster-01.yaml    # ArgoCD App for GKE
```

**clusters/aks-cluster-01.yaml:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-aks
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myapp-gitops
    targetRevision: main
    path: apps/myapp/overlays/aks-prod
  destination:
    server: https://aks-cluster-01.eastus.cloudapp.azure.com
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Single commit deploys to all clusters:**
```bash
# Update base deployment
vim apps/myapp/base/deployment.yaml
git commit -am "Update to v3"
git push

# ArgoCD automatically deploys to:
# - AKS cluster (with AKS-specific settings)
# - EKS cluster (with EKS-specific settings)
# - GKE cluster (with GKE-specific settings)

# View all deployments in ArgoCD UI
```

---

## Kustomize (Environment Variants)

**Problem:** Different environments need different configs

**Native kubectl approach (manual):**
```bash
# dev/deployment.yaml
replicas: 1
image: myapp:dev

# prod/deployment.yaml
replicas: 5
image: myapp:v1.0.0

kubectl apply -f dev/  # For dev cluster
kubectl apply -f prod/  # For prod cluster
# Result: Duplicate YAML, hard to maintain
```

**Kustomize approach (DRY):**

```yaml
# base/deployment.yaml (shared)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2  # Default
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:latest  # Default

# base/kustomization.yaml
resources:
- deployment.yaml
- service.yaml
```

```yaml
# overlays/dev/kustomization.yaml
bases:
- ../../base
replicas:
- name: myapp
  count: 1
images:
- name: myapp
  newTag: dev

# overlays/prod/kustomization.yaml
bases:
- ../../base
replicas:
- name: myapp
  count: 5
images:
- name: myapp
  newTag: v1.0.0
```

**Usage:**
```bash
# Native kubectl with Kustomize
kubectl apply -k overlays/dev/   # Dev cluster
kubectl apply -k overlays/prod/  # Prod cluster

# GitOps with ArgoCD
# ArgoCD automatically detects Kustomize and applies overlays
```

---

## GitOps Best Practices

### 1. Start with Manual Sync

```yaml
syncPolicy:
  # Manual sync first (learn, build confidence)
  # Auto-sync later (after you trust it)
```

### 2. Use Branches for Environments

```
main branch       → Production clusters
staging branch    → Staging clusters
dev branch        → Development clusters

# Deploy to dev first
git checkout dev
git commit -m "New feature"
git push

# Promote to staging
git checkout staging
git merge dev
git push

# Promote to production
git checkout main
git merge staging
git push
```

### 3. Protect Production

```yaml
# Require approval for production syncs
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
spec:
  destinations:
  - namespace: production
    server: https://prod-cluster.example.com
  # Require manual sync approval
  syncWindows:
  - kind: deny
    schedule: '0 0 * * *'  # No auto-sync
```

### 4. Monitor Sync Status

```bash
# ArgoCD CLI
argocd app list
argocd app get myapp

# Prometheus metrics
# ArgoCD exposes metrics for monitoring
# Alert on sync failures, drift detection
```

### 5. Secret Management

**Do NOT commit secrets to Git!**

```yaml
# Use Sealed Secrets (encrypted secrets in Git)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: mysecret
spec:
  encryptedData:
    password: AgByhH7...  # Encrypted, safe to commit

# OR use External Secrets Operator (fetch from vault)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: mysecret
spec:
  secretStoreRef:
    name: azure-keyvault
  target:
    name: mysecret
  data:
  - secretKey: password
    remoteRef:
      key: my-password
```

---

## Comparison: Native vs GitOps

| Aspect | Native kubectl | GitOps (ArgoCD/Flux) |
|--------|----------------|---------------------|
| **Deployment** | Manual `kubectl apply` | Automated sync from Git |
| **Source of Truth** | Cluster state | Git repository |
| **Audit Trail** | kubectl logs (limited) | Git commit history |
| **Rollback** | `kubectl rollout undo` | `git revert` |
| **Multi-Cluster** | Manual switching | Automated multi-cluster |
| **Drift Detection** | Manual `kubectl diff` | Automatic detection |
| **Learning Curve** | Low (start here) | Medium (after native) |
| **Complexity** | Low | Medium (extra components) |
| **Best For** | Learning, debugging | Production, teams, multi-env |

---

## When to Adopt GitOps

### You're Ready for GitOps When:

✅ You can deploy applications with kubectl without looking up commands
✅ You understand Deployments, Services, ConfigMaps, Secrets
✅ You've manually rolled back a failed deployment
✅ You've debugged pod issues with logs and events
✅ You understand what happens when you `kubectl apply`
✅ You're managing multiple environments (dev, staging, prod)
✅ You want automated deployments and drift detection

### You're NOT Ready for GitOps When:

❌ You're still learning Kubernetes basics
❌ You don't understand what kubectl commands do
❌ You haven't debugged a failed deployment
❌ You don't know how to read pod logs or events
❌ Single cluster, single environment (GitOps is overkill)

---

## Progressive Adoption

**Month 1-2: Native kubectl (Proxmox + Cloud)**
```bash
# Learn Kubernetes primitives
kubectl apply -f deployment.yaml
kubectl get pods
kubectl logs
kubectl describe
kubectl rollout
```

**Month 3: Git-Based Manual Deployment**
```bash
# Version control manifests
git commit -m "Update deployment"
git push

# Still apply manually
git pull
kubectl apply -f k8s/
```

**Month 4: GitOps with Manual Sync**
```bash
# Install ArgoCD
# Create apps with manual sync
# Click "Sync" button in UI to deploy
# Build confidence
```

**Month 5+: Full GitOps Automation**
```bash
# Enable auto-sync
# Git push → Auto-deploy
# Multi-cluster management
# Drift detection and self-healing
```

---

## Conclusion

**GitOps is powerful, but:**
- It abstracts kubectl operations
- You must understand what it's abstracting
- Master native kubectl first
- GitOps is the destination, not the starting point

**Recommended Path:**
1. **Now:** Learn native kubectl (Deployments, Services, HPA)
2. **Soon:** Version control manifests in Git, manual kubectl apply
3. **Later:** ArgoCD with manual sync (click to deploy)
4. **Advanced:** ArgoCD with auto-sync (full GitOps automation)

**Your Proxmox K8s cluster is perfect for learning native kubectl. Master that before cloud GitOps.**

---

## Resources

**Native kubectl:**
- Official docs: https://kubernetes.io/docs/reference/kubectl/
- kubectl cheatsheet: https://kubernetes.io/docs/reference/kubectl/cheatsheet/

**GitOps:**
- ArgoCD: https://argo-cd.readthedocs.io/
- Flux: https://fluxcd.io/
- GitOps principles: https://opengitops.dev/

**Practice:**
- Start on Proxmox (on-prem, safe to break)
- Graduate to cloud when confident
- GitOps when managing multiple environments

---

*Last Updated: 2026-01-02*
