# Claude's Working Notes - Token Conservation

## DO NOT:
- ❌ Run commands unnecessarily in terminal
- ❌ Display long file contents via `cat`
- ❌ Show repetitive command outputs
- ❌ Execute commands just to verify

## DO:
- ✅ Point to existing files with instructions
- ✅ Give short, direct guidance
- ✅ Reference documentation locations
- ✅ Trust the user can run commands
- ✅ **Create files for detailed content** - Keep terminal for brief directives only
  - Multi-step tutorials → Create tutorial files
  - YAML manifests → Create .yaml files
  - Complex commands → Create .sh scripts with comments
  - Explanations → Create .md documentation
  - **Terminal:** Only brief navigation ("Run ./script.sh", "See tutorial.md")

---

# Learning Approach - Hybrid Mode (Managed with Awareness)

## Core Philosophy:
**Use managed tools for productivity, BUT always explain the native Kubernetes resources they create.**

## When Using Managed Tools:

### ALWAYS explain the mapping:
```
Managed Tool/Operator
  ↓ (what it creates)
Native K8s Resources
  ↓ (how to inspect)
kubectl commands to view
```

### Examples:

**local-path-provisioner:**
```
Managed: StorageClass with provisioner
  ↓ creates
Native: PersistentVolume (PV) + PVC binding
  ↓ inspect
kubectl get pv, kubectl get storageclass
```

**MetalLB:**
```
Managed: MetalLB controller + speaker DaemonSet
  ↓ watches
Native: Service type=LoadBalancer
  ↓ assigns
External IP from IPAddressPool
  ↓ inspect
kubectl get svc, kubectl describe svc <name>
```

**OpenFaaS (when used later):**
```
Managed: faas-cli deploy
  ↓ creates
Native: Deployment + Service + HPA + ConfigMap
  ↓ inspect
kubectl get deployment,svc,hpa -n openfaas-fn
```

**Helm (when used later):**
```
Managed: helm install <chart>
  ↓ creates
Native: Multiple K8s resources (varies by chart)
  ↓ inspect
helm get manifest <release>, kubectl get all -l app=<name>
```

## Teaching Pattern:

1. **First time:** Explain both managed and native
2. **Show inspection:** Demonstrate kubectl commands to view native resources
3. **Encourage exploration:** "Check what resources it created with kubectl get..."
4. **Compare:** Show native manual approach vs managed approach

## Goal:
User should always know:
- What native resources exist
- How to inspect them
- How to debug when managed tools fail
- Why the managed tool is useful (what manual work it saves)
