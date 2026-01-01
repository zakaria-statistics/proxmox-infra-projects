# Switch to Custom K8s MCP Server

## Why Switch?

**Official MCP (current):**
- ✅ Auto-updates
- ✅ Read-only (safe)
- ❌ Limited to 5 resources

**Custom MCP (in k8s-platform/mcp-server/):**
- ✅ 12+ kubectl operations
- ✅ Can execute actions (apply, delete, scale, rollout)
- ✅ Get logs, exec into pods, port-forward
- ❌ Need to maintain yourself

## How to Switch

### Option 1: Replace Official with Custom

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

### Option 2: Run Both (Recommended)

Keep official for reading, add custom for actions:

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

### Install Dependencies First

```bash
cd /root/claude/k8s-platform/mcp-server
npm install @modelcontextprotocol/sdk
chmod +x server.js
```

### Test It Works

```bash
node server.js --kubeconfig /root/.kube/config
# Should see: [INFO] Kubernetes MCP Server started
# Press Ctrl+C to exit
```

## What You'll Be Able to Do

After switching, ask me:

```
"Deploy this YAML to the cluster"
"Scale the deployment to 3 replicas"
"Show me logs from the nginx pod"
"Execute 'ls /' in the app container"
"Delete the old deployment"
"Rollback the deployment"
```

## Recommendation

**For learning:** Use custom MCP (more features to explore)
**For production:** Use official MCP (safer, read-only)
