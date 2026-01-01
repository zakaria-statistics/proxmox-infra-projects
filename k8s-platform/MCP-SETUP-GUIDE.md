# Kubernetes MCP Server Setup - Natural Language Cluster Management

## What This Gives You

After setup, you can ask Claude in natural language:
- "Show me all failing pods"
- "Why is the nginx deployment not running?"
- "List pods using more than 100MB memory"
- "Get logs from all pods in the default namespace"
- "Describe the metallb-system namespace"
- "Show me services with external IPs"

Claude will **directly query your cluster** and give you answers with context.

---

## Installation Options

### Option 1: Official Kubernetes MCP Server (Recommended)

This is the most feature-rich option with full kubectl functionality.

```bash
# Install the Kubernetes MCP server
claude mcp add --transport stdio k8s -- npx -y @modelcontextprotocol/server-kubernetes \
  --kubeconfig ~/.kube/config \
  --scope project

# This creates .mcp.json in your project root
```

**What it provides:**
- `kubectl_get` - Get resources
- `kubectl_describe` - Describe resources
- `kubectl_logs` - Get logs
- `kubectl_exec` - Execute commands in pods
- `kubectl_apply` - Apply manifests
- `kubectl_delete` - Delete resources
- And more...

### Option 2: Custom kubectl Wrapper (Lightweight)

Simpler but less structured:

```bash
claude mcp add --transport stdio kubectl -- bash -c \
  'kubectl --kubeconfig=/root/.kube/config "$@"' -- \
  --scope project
```

### Option 3: Multiple Contexts (Advanced)

If you manage multiple clusters:

```bash
# Production cluster
claude mcp add --transport stdio k8s-prod -- npx -y @modelcontextprotocol/server-kubernetes \
  --kubeconfig ~/.kube/config \
  --context prod-cluster \
  --scope project

# Dev cluster
claude mcp add --transport stdio k8s-dev -- npx -y @modelcontextprotocol/server-kubernetes \
  --kubeconfig ~/.kube/config \
  --context dev-cluster \
  --scope project
```

---

## Configuration File

After running the command, check `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "k8s": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-kubernetes",
        "--kubeconfig",
        "/root/.kube/config"
      ]
    }
  }
}
```

**Important:**
- This file should be committed to git if you want team access
- Use absolute paths for `--kubeconfig`
- Claude Code will ask for approval first time it uses project-scoped servers

---

## Verification

### 1. Check MCP Server Registration

```bash
claude mcp list
```

Expected output:
```
k8s (stdio) - npx -y @modelcontextprotocol/server-kubernetes
```

### 2. Test in Claude Code

```bash
claude
```

Then in the Claude session:
```
> /mcp
```

You should see:
- ✅ k8s (connected)

### 3. Try a Query

```
> What pods are running in kube-system namespace?
```

Claude should directly query your cluster and show results.

---

## Natural Language Query Examples

### Cluster Health
```
"Show me cluster health"
"Are all nodes ready?"
"What's the cluster version?"
"Show me system pods that aren't running"
```

### Pod Management
```
"List all pods across all namespaces"
"Show me failing pods"
"Why is the nginx pod not starting?"
"Get logs from the metallb speaker pod"
"Show me pods using the most CPU"
"Which pods are in CrashLoopBackOff?"
```

### Deployments & Services
```
"Describe the nginx deployment"
"Show me all deployments in default namespace"
"Scale the nginx deployment to 3 replicas"
"What services have external IPs?"
"Show me the endpoints for the nginx service"
```

### Storage
```
"List all PVCs and their status"
"Show me unbound PVCs"
"What PVs are available?"
"Which pods are using persistent storage?"
```

### Networking
```
"Show me all LoadBalancer services"
"What ingresses are configured?"
"Get the nginx ingress configuration"
"Show me network policies"
```

### Debugging
```
"Show me recent events in the default namespace"
"Why is pod X failing?"
"Get the previous logs from pod Y"
"Execute 'ls /' in the nginx pod"
"Show me resource usage for all pods"
```

### Resource References
```
"Check @k8s:pod://default/nginx"
"Inspect @k8s:deployment://default/nginx"
"Show @k8s:service://metallb-system/metallb-webhook-service"
```

### Complex Queries
```
"Show me all pods created in the last hour that are not running"
"List deployments with less than 2 replicas"
"Find all services without endpoints"
"Show me pods that have restarted more than 3 times"
```

---

## MCP Tools Available

Once connected, Claude has access to these kubectl tools:

| Tool | What It Does | Example Use |
|------|--------------|-------------|
| `kubectl_get` | Get resources | List pods, services, deployments |
| `kubectl_describe` | Detailed resource info | Why is this pod failing? |
| `kubectl_logs` | Container logs | Show me logs from nginx |
| `kubectl_exec` | Execute commands | Run a command inside a pod |
| `kubectl_apply` | Apply manifests | Deploy this YAML |
| `kubectl_delete` | Delete resources | Remove this deployment |
| `kubectl_scale` | Scale workloads | Scale to 5 replicas |
| `kubectl_rollout` | Manage rollouts | Rollback this deployment |
| `kubectl_port_forward` | Port forwarding | Forward port 8080 |
| `kubectl_top` | Resource usage | CPU/Memory usage |

---

## Advanced Usage

### 1. Namespace Scoping

```bash
# Scope MCP server to specific namespace
claude mcp add --transport stdio k8s-prod -- npx -y @modelcontextprotocol/server-kubernetes \
  --kubeconfig ~/.kube/config \
  --namespace production \
  --scope project
```

### 2. RBAC-Limited Access

Create a service account with limited permissions:

```yaml
# limited-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: claude-mcp-readonly
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: readonly-cluster
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "describe"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: claude-mcp-readonly-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: readonly-cluster
subjects:
- kind: ServiceAccount
  name: claude-mcp-readonly
  namespace: default
```

Apply and get token:
```bash
kubectl apply -f limited-sa.yaml
kubectl create token claude-mcp-readonly --duration=87600h > /tmp/mcp-token

# Use this token in MCP config
claude mcp add --transport stdio k8s -- npx -y @modelcontextprotocol/server-kubernetes \
  --kubeconfig ~/.kube/config \
  --token "$(cat /tmp/mcp-token)" \
  --scope project
```

### 3. Environment Variables

Add custom kubeconfig path via environment:

```json
{
  "mcpServers": {
    "k8s": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-kubernetes"],
      "env": {
        "KUBECONFIG": "/root/.kube/config",
        "KUBECTL_CONTEXT": "my-cluster"
      }
    }
  }
}
```

---

## Troubleshooting

### MCP Server Not Found

```bash
# Verify npm/npx is available
npx -y @modelcontextprotocol/server-kubernetes --version

# If fails, install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Permission Denied

```bash
# Check kubeconfig permissions
ls -la ~/.kube/config
chmod 600 ~/.kube/config

# Test kubectl works
kubectl cluster-info
```

### Server Not Connecting

```bash
# Remove and re-add
claude mcp remove k8s
claude mcp add --transport stdio k8s -- npx -y @modelcontextprotocol/server-kubernetes \
  --kubeconfig ~/.kube/config \
  --scope project

# Check logs
claude --verbose
```

### Wrong Cluster Context

```bash
# Check current context
kubectl config current-context

# Set correct context
kubectl config use-context <cluster-name>

# Or specify in MCP config
claude mcp add --transport stdio k8s -- npx -y @modelcontextprotocol/server-kubernetes \
  --kubeconfig ~/.kube/config \
  --context <cluster-name> \
  --scope project
```

---

## Security Best Practices

1. **Use Read-Only Service Accounts** for MCP in production
2. **Scope to Specific Namespaces** when possible
3. **Don't Commit Tokens** to git (use `--scope local` for sensitive configs)
4. **Audit MCP Access** regularly with `kubectl auth can-i --list`
5. **Use Short-Lived Tokens** (`kubectl create token --duration=24h`)

---

## IntelliJ IDE Integration

### Enable Claude Code Plugin

1. **Settings → Plugins → Marketplace**
2. Search "Claude Code (Beta)"
3. Install and restart IntelliJ

### Use MCP in IDE

1. Open terminal in IntelliJ: **View → Tool Windows → Terminal**
2. Run: `claude`
3. Use `/ide` to connect to IDE window
4. Ask natural language K8s questions

### Workflow

```
Terminal 1 (IntelliJ): claude    # MCP-enabled session
Terminal 2 (IntelliJ): k9s       # Visual cluster view
Terminal 3 (IntelliJ): stern . -A # Log streaming
```

**Example IDE workflow:**
1. Browse YAML file in editor
2. Ask Claude: "Is this deployment currently running in the cluster?"
3. Claude checks via MCP and tells you the live state
4. Make edits based on actual cluster state
5. Ask: "Apply this file to the cluster"

---

## Example Session

```bash
$ claude
Claude Code CLI v1.x.x

> /mcp
✅ k8s (connected)

> Show me all pods in kube-system that aren't running

Let me check the kube-system namespace...

[Claude uses kubectl_get tool via MCP]

I found 0 pods that aren't running in kube-system. All system pods are healthy:
- coredns-xxxxx (2/2 Running)
- etcd-control-plane (1/1 Running)
- kube-apiserver-control-plane (1/1 Running)
- kube-controller-manager-control-plane (1/1 Running)
- kube-proxy-xxxxx (1/1 Running)
- kube-scheduler-control-plane (1/1 Running)

Your cluster system components are all healthy! ✓

> Why might a pod be in ImagePullBackOff state?

[Claude provides expert explanation without needing MCP tools]

> Check if there are any pods in that state right now

[Claude uses kubectl_get with field selector via MCP]

Good news - I don't see any pods in ImagePullBackOff state in your cluster.

> Create a test deployment with a bad image to demonstrate

[Claude can use kubectl_apply if you want]
```

---

## Next Steps

1. **Install the MCP server** (run command below)
2. **Test with `/mcp`** in Claude Code
3. **Try natural language queries** from examples above
4. **Keep k9s open** alongside Claude for visual feedback
5. **Commit `.mcp.json`** to git for team access

---

## Quick Install Command

```bash
cd /root/claude/k8s-platform
claude mcp add --transport stdio k8s -- npx -y @modelcontextprotocol/server-kubernetes \
  --kubeconfig ~/.kube/config \
  --scope project
```

Then verify:
```bash
claude mcp list
claude
# In claude: /mcp
```

**You're ready to debug Kubernetes with natural language! 🚀**
