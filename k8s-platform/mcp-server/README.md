# Custom Kubernetes MCP Server

**Natural language Kubernetes cluster management and debugging via Model Context Protocol**

## What This Does

This MCP server exposes kubectl commands through structured tools that Claude can use to:
- Answer questions about your cluster state
- Debug failing pods and services
- Get logs and events
- Execute commands in containers
- Manage deployments and scaling
- All using **natural language**!

---

## Installation

### Option 1: Use Existing mcp-server-kubernetes (Already Configured)

You already have `mcp-server-kubernetes` configured in `/root/claude/.mcp.json`:

```bash
# Verify it's working
claude mcp list

# Should show:
# k8s: npx -y mcp-server-kubernetes --kubeconfig /root/.kube/config - ✓ Connected
```

### Option 2: Use This Custom Server

```bash
cd /root/claude/k8s-platform/mcp-server

# Install dependencies
npm install

# Test it works
node server.js --kubeconfig ~/.kube/config

# Make it executable
chmod +x server.js
```

Then update `.mcp.json` to use your custom server:

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

Or add it as a second server:

```json
{
  "mcpServers": {
    "k8s": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "mcp-server-kubernetes", "--kubeconfig", "/root/.kube/config"]
    },
    "k8s-custom": {
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

---

## Available Tools

The MCP server provides these kubectl tools to Claude:

### 1. `kubectl_get` - Get Resources

**Get any Kubernetes resource with filtering and formatting**

Examples Claude can do:
- "Show me all pods"
- "List services in the default namespace"
- "Get deployments with label app=nginx"
- "Show failing pods across all namespaces"
- "List all PVCs in YAML format"

**Parameters:**
- `resource` (required): pods, services, deployments, nodes, pvc, pv, ingress, all, etc.
- `namespace` (optional): Specific namespace or "all" for all namespaces
- `name` (optional): Specific resource name
- `output` (optional): wide, yaml, json, name
- `selector` (optional): Label selector (e.g., `app=nginx`)
- `fieldSelector` (optional): Field selector (e.g., `status.phase=Failed`)

---

### 2. `kubectl_describe` - Detailed Resource Info

**Get full description including events and conditions**

Examples:
- "Describe the nginx pod"
- "Why is this deployment not ready?"
- "Show me details of the worker-1 node"

**Parameters:**
- `resource` (required): pod, service, deployment, node, etc.
- `name` (required): Resource name
- `namespace` (optional): For namespaced resources

---

### 3. `kubectl_logs` - Get Container Logs

**View logs from pods with filtering**

Examples:
- "Get logs from nginx pod"
- "Show me last 100 lines from the app container"
- "Get previous logs from crashed pod"
- "Show logs from the last 5 minutes"

**Parameters:**
- `pod` (required): Pod name
- `namespace` (optional): Namespace (default: default)
- `container` (optional): Container name (required for multi-container pods)
- `previous` (optional): Get logs from previous crashed container
- `tail` (optional): Number of lines from end
- `since` (optional): Time duration (e.g., 1h, 30m, 10s)

---

### 4. `kubectl_exec` - Execute Commands in Pods

**Run commands inside containers for debugging**

Examples:
- "Run 'ls /' in the nginx pod"
- "Check /etc/hosts in the app container"
- "Test network with curl from pod"

**Parameters:**
- `pod` (required): Pod name
- `command` (required): Command to execute
- `namespace` (optional): Namespace
- `container` (optional): Container name (for multi-container pods)

---

### 5. `kubectl_get_events` - Cluster Events

**See what's happening in the cluster (critical for debugging)**

Examples:
- "Show me recent cluster events"
- "Get events from the default namespace"
- "What events happened in kube-system?"

**Parameters:**
- `namespace` (optional): Specific namespace or "all"
- `sort` (optional): Sort by timestamp (default: true)
- `tail` (optional): Show only last N events

---

### 6. `kubectl_top` - Resource Usage

**CPU and memory usage (requires metrics-server)**

Examples:
- "Show node resource usage"
- "Which pods are using the most memory?"
- "Get CPU usage for all pods"

**Parameters:**
- `resource` (required): nodes or pods
- `namespace` (optional): For pods only
- `sortBy` (optional): cpu or memory

---

### 7. `kubectl_apply` - Apply Manifests

**Create or update resources declaratively**

Examples:
- "Apply this deployment manifest"
- "Create a service from this YAML"
- "Dry-run apply to validate manifest"

**Parameters:**
- `manifest` (required): YAML content
- `namespace` (optional): Target namespace
- `dryRun` (optional): Validate without applying

---

### 8. `kubectl_delete` - Delete Resources

**Remove resources from cluster**

Examples:
- "Delete the test pod"
- "Remove the old deployment"

**Parameters:**
- `resource` (required): Resource type
- `name` (required): Resource name
- `namespace` (optional): Namespace
- `force` (optional): Force immediate deletion

---

### 9. `kubectl_scale` - Scale Workloads

**Change replica count**

Examples:
- "Scale nginx deployment to 5 replicas"
- "Scale down to 0 replicas"

**Parameters:**
- `resource` (required): deployment, replicaset, or statefulset
- `name` (required): Resource name
- `replicas` (required): Desired count
- `namespace` (optional): Namespace

---

### 10. `kubectl_rollout` - Manage Rollouts

**Control deployment updates**

Examples:
- "Check rollout status of nginx deployment"
- "Restart the app deployment"
- "Undo last deployment"
- "Show rollout history"

**Parameters:**
- `action` (required): status, restart, undo, or history
- `resource` (required): Usually deployment
- `name` (required): Resource name
- `namespace` (optional): Namespace

---

### 11. `kubectl_cluster_info` - Cluster Information

**Get cluster endpoints and status**

Examples:
- "Show cluster info"
- "Get cluster health"

**Parameters:**
- `dump` (optional): Full cluster dump for debugging

---

### 12. `kubectl_port_forward` - Port Forwarding

**Forward local port to pod (returns command to run manually)**

Examples:
- "How do I port-forward to nginx pod port 80?"

**Parameters:**
- `resource` (required): Resource identifier (e.g., pod/nginx)
- `localPort` (required): Local port number
- `remotePort` (required): Remote port number
- `namespace` (optional): Namespace

---

## Usage Examples

### Start Claude Code Session with MCP

```bash
claude
```

In Claude Code:
```
> /mcp
✅ k8s (connected)

> Show me all pods in kube-system
[Claude uses kubectl_get tool]

> Why is the nginx pod not starting?
[Claude uses kubectl_describe + kubectl_get_events + kubectl_logs]

> Get the last 50 lines of logs from metallb speaker pod
[Claude uses kubectl_logs with tail parameter]

> Scale the nginx deployment to 3 replicas
[Claude uses kubectl_scale]

> Show me which pods are using the most CPU
[Claude uses kubectl_top with sortBy]
```

### Natural Language Debugging Workflow

```
You: "Something is wrong with my nginx deployment"

Claude: Let me investigate...
[Uses kubectl_get to check deployment status]
[Uses kubectl_describe to see deployment details]
[Uses kubectl_get to check pod status]
[Uses kubectl_describe on failing pod]
[Uses kubectl_get_events to see related events]
[Uses kubectl_logs to check container output]

Claude: "The pod is failing because of ImagePullBackOff. The image name
         'nginx:latst' has a typo - should be 'nginx:latest'. Here's how
         to fix it..."
```

### Complex Queries

```
> "Find all pods that have restarted more than 3 times"
[Claude uses kubectl_get with custom output and filters]

> "Show me all LoadBalancer services and their external IPs"
[Claude uses kubectl_get services with field selector]

> "Which namespaces have pods in CrashLoopBackOff?"
[Claude uses kubectl_get across all namespaces with filters]

> "Debug why my service can't reach its pods"
[Claude uses kubectl_get service, kubectl_get endpoints,
        kubectl_describe service, checks label selectors]
```

---

## How It Works

1. **You ask in natural language**
   - "Show me failing pods"
   - "Why is nginx not working?"

2. **Claude understands your intent**
   - Determines which tools to use
   - Plans the debugging sequence

3. **MCP server executes kubectl**
   - Runs appropriate kubectl commands
   - Returns structured results

4. **Claude interprets and explains**
   - Analyzes the output
   - Explains what's wrong
   - Suggests fixes

---

## Debugging the MCP Server

### Check if server is running

```bash
claude mcp list
```

### Test kubectl connectivity

```bash
kubectl cluster-info
kubectl get nodes
```

### View MCP server logs

```bash
# MCP servers log to stderr
node server.js --kubeconfig ~/.kube/config 2>&1 | tee mcp-debug.log
```

### Verify tools are available

In Claude Code:
```
> /mcp
```

Should show connected servers and available tools.

---

## Security Notes

- **Read-only recommended**: For safety, consider using a read-only kubeconfig
- **RBAC limits**: The MCP server uses your kubeconfig permissions
- **Audit access**: kubectl commands are logged with `[DEBUG]` prefix

### Create read-only service account

```bash
kubectl create serviceaccount claude-readonly
kubectl create clusterrolebinding claude-readonly \
  --clusterrole=view \
  --serviceaccount=default:claude-readonly

# Get token and use it in kubeconfig
```

---

## Customization

### Add custom tools

Edit `server.js` and add to the `tools` array in `ListToolsRequestSchema`:

```javascript
{
  name: 'kubectl_custom',
  description: 'Your custom kubectl command',
  inputSchema: {
    type: 'object',
    properties: {
      // Your parameters
    },
    required: ['...'],
  },
}
```

Then handle it in `CallToolRequestSchema`.

### Modify kubectl options

All tools use the `runKubectl()` function. Add global options there:

```javascript
const cmd = `${KUBECTL_BIN} --kubeconfig=${KUBECONFIG} --request-timeout=30s ${cmdArgs}`;
```

---

## Comparison: Existing vs Custom Server

| Feature | Existing (mcp-server-kubernetes) | Custom (This Server) |
|---------|----------------------------------|---------------------|
| Installation | Already configured ✅ | Need to install dependencies |
| Maintenance | Auto-updated via npx | Manual updates |
| Customization | Limited | Full control |
| Tools | Predefined | Can add custom tools |
| Learning | Use as-is | See implementation |
| Debugging | Black box | Full visibility |

**Recommendation:** Use the existing server for production, keep this custom one for:
- Learning how MCP works
- Adding custom kubectl wrappers
- Debugging MCP issues
- Experimenting with new features

---

## Troubleshooting

### "kubectl: command not found"

```bash
which kubectl
# If missing:
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### "Error: Kubeconfig not found"

```bash
# Check kubeconfig exists
ls -la ~/.kube/config

# Verify it works
kubectl cluster-info
```

### "MCP server not connecting"

```bash
# Remove and re-add
claude mcp remove k8s
claude mcp add --transport stdio k8s -- node /root/claude/k8s-platform/mcp-server/server.js --kubeconfig /root/.kube/config --scope project
```

### "npm install fails"

```bash
# Check Node.js version
node --version  # Should be >= 18

# Clean install
cd /root/claude/k8s-platform/mcp-server
rm -rf node_modules package-lock.json
npm install
```

---

## Next Steps

1. ✅ Server files created in `/root/claude/k8s-platform/mcp-server/`
2. ⏭️ You already have `mcp-server-kubernetes` configured and working
3. ⏭️ Install custom server if you want to customize: `cd mcp-server && npm install`
4. ⏭️ Start using it: `claude` then `/mcp`
5. ⏭️ Try natural language queries: "Show me all failing pods"

**Your cluster is ready for natural language management! 🚀**
