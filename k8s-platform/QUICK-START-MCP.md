# Kubernetes MCP - Quick Start Guide

## ✅ What You Have Now

### 1. MCP Server (Already Configured!)
- **Location:** `/root/claude/.mcp.json`
- **Server:** `mcp-server-kubernetes`
- **Status:** ✅ Connected and working

### 2. Custom MCP Server (For Learning/Customization)
- **Location:** `/root/claude/k8s-platform/mcp-server/`
- **Files:**
  - `server.js` - Full MCP server implementation
  - `package.json` - Node.js package configuration
  - `README.md` - Complete documentation

### 3. Complete K8s Debugging Guides
- `K8S-DEEP-DIVE.md` - Comprehensive Kubernetes debugging guide
- `k8s-debug-cheatsheet.md` - Quick reference card
- `MCP-SETUP-GUIDE.md` - MCP configuration documentation

---

## 🚀 Start Using MCP Right Now

### Step 1: Verify MCP is Working

```bash
claude mcp list
```

Expected output:
```
k8s: npx -y mcp-server-kubernetes --kubeconfig /root/.kube/config - ✓ Connected
```

### Step 2: Start Claude Code Session

```bash
claude
```

### Step 3: Check MCP Status

```
> /mcp
```

You should see:
```
✅ k8s (connected)
```

### Step 4: Try Natural Language Queries

```
> Show me all pods in kube-system namespace

> Are there any failing pods in the cluster?

> What's the status of the control plane?

> Get logs from the coredns pod

> Describe the nginx deployment

> Show me recent cluster events
```

---

## 🎯 Example Natural Language Debugging Session

```
You: "Check if my cluster is healthy"

Claude:
[Uses kubectl_cluster_info]
[Uses kubectl_get nodes]
[Uses kubectl_get pods in kube-system]
[Uses kubectl_get_events]

"Your cluster is healthy! All nodes are Ready, all system pods are Running,
and there are no error events in the last hour."

---

You: "I deployed nginx but can't access it"

Claude:
[Uses kubectl_get deployment nginx]
[Uses kubectl_get pods -l app=nginx]
[Uses kubectl_describe pod nginx-xxx]
[Uses kubectl_get service nginx]
[Uses kubectl_get endpoints nginx]

"I found the issue. Your nginx deployment is running (3/3 pods ready), but
there's no Service exposing it. You need to create a Service to access the pods.

Would you like me to help create a LoadBalancer service?"

---

You: "Yes, create a LoadBalancer service for nginx"

Claude:
[Uses kubectl_apply with Service manifest]

"Service created! Here's what I did:
- Created LoadBalancer service 'nginx-service'
- Exposed port 80
- MetalLB assigned external IP: 192.168.1.100

Test it with: curl http://192.168.1.100"
```

---

## 🔧 Available MCP Tools

Claude can use these tools to manage your cluster:

| Tool | Purpose | Example Query |
|------|---------|---------------|
| `kubectl_get` | List resources | "Show me all deployments" |
| `kubectl_describe` | Resource details | "Describe the nginx pod" |
| `kubectl_logs` | Container logs | "Get logs from coredns" |
| `kubectl_exec` | Run commands in pods | "Run ls in the nginx container" |
| `kubectl_get_events` | Cluster events | "Show recent events" |
| `kubectl_top` | Resource usage | "Which pods use most CPU?" |
| `kubectl_apply` | Create/update resources | "Apply this manifest" |
| `kubectl_delete` | Delete resources | "Delete the test pod" |
| `kubectl_scale` | Scale workloads | "Scale nginx to 5 replicas" |
| `kubectl_rollout` | Manage rollouts | "Restart nginx deployment" |
| `kubectl_cluster_info` | Cluster info | "Show cluster health" |

Full documentation: `mcp-server/README.md`

---

## 💬 Natural Language Examples

### Cluster Health
```
"Is my cluster healthy?"
"Show me node status"
"Are all system pods running?"
"What errors happened recently?"
```

### Pod Debugging
```
"Why is my nginx pod not starting?"
"Show me failing pods"
"Get logs from the crashed container"
"What's in CrashLoopBackOff?"
```

### Service & Networking
```
"List all LoadBalancer services"
"Why can't I reach my service?"
"Show me ingress configurations"
"Check service endpoints"
```

### Resource Management
```
"Which pods are using the most memory?"
"Show me node resource usage"
"Scale nginx to 3 replicas"
"Restart the app deployment"
```

### Storage
```
"List all PVCs"
"Which PVs are available?"
"Show me storage classes"
"What pods are using persistent storage?"
```

---

## 🛠️ Using the Custom MCP Server (Optional)

If you want to customize or learn how MCP works:

### Install Custom Server

```bash
cd /root/claude/k8s-platform/mcp-server
npm install
```

### Test It

```bash
node server.js --kubeconfig /root/.kube/config
# Press Ctrl+C to stop
```

### Switch to Custom Server

Edit `/root/claude/.mcp.json`:

```json
{
  "mcpServers": {
    "k8s": {
      "type": "stdio",
      "command": "node",
      "args": [
        "/root/claude/k8s-platform/mcp-server/server.js",
        "--kubeconfig",
        "/root/.kube/config"
      ]
    }
  }
}
```

### Add Custom Tools

Edit `server.js` and add your own kubectl wrappers!

---

## 📊 Complete Workflow

```
Terminal 1: claude              # MCP-enabled Claude session
Terminal 2: k9s                 # Visual cluster view
Terminal 3: stern . -A          # Live log streaming
Terminal 4: Your work terminal
```

**Workflow:**
1. Browse code/manifests in your IDE
2. Ask Claude (with MCP): "Is this deployment running?"
3. Claude checks cluster and tells you the live state
4. Make changes based on actual cluster state
5. Ask Claude: "Apply this updated manifest"
6. Verify in k9s

---

## 🎓 Learning Path

### Week 1: Basic MCP Usage
- Start Claude sessions with `/mcp`
- Ask simple queries about pod status
- Use Claude to explain kubectl output
- Let Claude help debug one failing pod

### Week 2: Advanced Debugging
- Use Claude for complex multi-step debugging
- Ask Claude to analyze events + logs together
- Have Claude compare manifest vs running state
- Use Claude to troubleshoot networking issues

### Week 3: Management Operations
- Ask Claude to scale deployments
- Have Claude apply manifests with validation
- Use Claude for rollout management
- Let Claude help with resource optimization

### Week 4: Custom Automation
- Modify custom MCP server
- Add your own kubectl wrappers
- Create custom debugging workflows
- Integrate with your CI/CD

---

## 🔒 Security Best Practices

1. **Use read-only kubeconfig** for exploration
2. **Review before destructive operations** (delete, force, etc.)
3. **Audit MCP access** - all kubectl commands are logged
4. **Limit RBAC** - MCP uses your kubeconfig permissions
5. **Don't commit tokens** - use `--scope local` for sensitive configs

---

## 📚 Complete Documentation

- **MCP Tools Reference:** `mcp-server/README.md`
- **K8s Deep Dive:** `K8S-DEEP-DIVE.md`
- **Debug Cheatsheet:** `k8s-debug-cheatsheet.md`
- **MCP Setup Guide:** `MCP-SETUP-GUIDE.md`

---

## ✨ You're Ready!

**MCP is already configured and working!**

Try it now:
```bash
claude
> /mcp
> Show me all pods
```

**Natural language Kubernetes debugging is now available! 🚀**
