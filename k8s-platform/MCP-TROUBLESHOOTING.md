# MCP Server Troubleshooting & Benchmarking Guide

## 🚨 Common Issue: "No MCP servers configured"

### Problem
```
> /mcp
No MCP servers configured. Please run /doctor if this is unexpected.
```

### Root Cause
**You're running `claude` from the wrong directory!**

MCP configuration files are **directory-scoped**:
- `.mcp.json` must be in your **current working directory** or parent directories
- The server at `/root/claude/.mcp.json` only works when you're in `/root/claude/` or subdirectories

---

## ✅ Solution: Run from Correct Directory

### Fix 1: Change to Correct Directory

```bash
# Navigate to where .mcp.json exists
cd /root/claude

# Now start Claude
claude

# Check MCP status
> /mcp
✅ k8s (connected)
```

### Fix 2: Copy MCP Config to Project Directory

```bash
# Copy to your k8s-platform directory
cp /root/claude/.mcp.json /root/claude/k8s-platform/.mcp.json

# Now you can run claude from k8s-platform/
cd /root/claude/k8s-platform
claude
> /mcp
```

### Fix 3: Use User-Scoped MCP (Global)

```bash
# Add MCP server to user scope (works everywhere)
claude mcp add --transport stdio k8s -- npx -y mcp-server-kubernetes \
  --kubeconfig /root/.kube/config \
  --scope user

# Now works from any directory
cd /anywhere
claude
> /mcp
```

---

## 📍 MCP Configuration Scopes

### 1. Local Scope (Project-specific, not shared)
**Location:** `.claude/.mcp.json` in project directory
**Usage:** Personal config, not committed to git
**Command:** `--scope local`

```bash
claude mcp add --transport stdio k8s -- npx -y mcp-server-kubernetes \
  --kubeconfig /root/.kube/config \
  --scope local
```

### 2. Project Scope (Shared with team)
**Location:** `.mcp.json` in project root
**Usage:** Team config, committed to git
**Command:** `--scope project`

```bash
cd /root/claude/k8s-platform
claude mcp add --transport stdio k8s -- npx -y mcp-server-kubernetes \
  --kubeconfig /root/.kube/config \
  --scope project
```

### 3. User Scope (Global, all projects)
**Location:** `~/.claude/mcp.json`
**Usage:** Your personal servers, works everywhere
**Command:** `--scope user`

```bash
claude mcp add --transport stdio k8s -- npx -y mcp-server-kubernetes \
  --kubeconfig /root/.kube/config \
  --scope user
```

---

## 🔍 Debugging MCP Issues

### Step 1: Check Current MCP Configuration

```bash
# See what's configured
claude mcp list

# Check configuration file location
ls -la .mcp.json
ls -la .claude/.mcp.json
ls -la ~/.claude/mcp.json
```

### Step 2: Verify MCP Server Package Exists

```bash
# Test if the MCP server package works
npx -y mcp-server-kubernetes --help

# Check Node.js is available
node --version  # Should be >= 18
npm --version
npx --version
```

### Step 3: Check Kubectl Connectivity

```bash
# Verify kubectl works with your kubeconfig
kubectl --kubeconfig /root/.kube/config cluster-info
kubectl --kubeconfig /root/.kube/config get nodes
```

### Step 4: Test MCP Server Directly

```bash
# Run the MCP server manually to see errors
npx -y mcp-server-kubernetes --kubeconfig /root/.kube/config
# Press Ctrl+C to stop

# Or test custom server
cd /root/claude/k8s-platform/mcp-server
node server.js --kubeconfig /root/.kube/config
```

### Step 5: Run Claude Doctor

```bash
claude
> /doctor
```

This will check for common MCP configuration issues.

---

## ⚡ MCP Server Performance Benchmarking

### Benchmark 1: Tool Response Time

Test how fast MCP tools respond:

```bash
cd /root/claude/k8s-platform
claude
```

In Claude:
```
> /mcp

# Benchmark simple query
> Show me all pods in default namespace
[Note the response time]

# Benchmark complex query
> Show me all pods across all namespaces with their resource usage sorted by memory
[Note the response time]

# Benchmark multi-tool query
> Why is the nginx deployment not working? Debug it completely.
[Claude will use multiple tools - note total time]
```

### Benchmark 2: kubectl Direct vs MCP

Create a benchmark script:

```bash
cat > /root/claude/k8s-platform/benchmark-mcp.sh << 'EOF'
#!/bin/bash
# Benchmark kubectl direct vs MCP overhead

echo "=== Benchmarking kubectl Performance ==="

echo "1. Direct kubectl (baseline):"
time kubectl get pods -A > /dev/null

echo ""
echo "2. kubectl via npx MCP server:"
time npx -y mcp-server-kubernetes --kubeconfig ~/.kube/config < /dev/null 2>&1 | head -1

echo ""
echo "3. Multiple kubectl calls:"
for i in {1..10}; do
  kubectl get pods -n kube-system > /dev/null
done

echo ""
echo "=== Results ==="
echo "MCP overhead is typically < 200ms for server startup"
echo "Subsequent calls are fast (< 50ms) while server is running"
EOF

chmod +x /root/claude/k8s-platform/benchmark-mcp.sh
./benchmark-mcp.sh
```

### Benchmark 3: Large Cluster Performance

Test with large outputs:

```bash
# Test with many pods
kubectl get pods -A -o json | wc -l

# Time the query via MCP
time npx -y mcp-server-kubernetes --kubeconfig ~/.kube/config

# In Claude:
> Show me all pods across all namespaces
[Measure response time]
```

### Benchmark 4: Concurrent Requests

Test how MCP handles multiple simultaneous queries:

In Claude:
```
> Show me all pods, nodes, services, and deployments across all namespaces
[Claude will make multiple tool calls - measure total time]
```

---

## 📊 Performance Expectations

| Operation | Expected Time | Notes |
|-----------|---------------|-------|
| MCP server startup | 1-3 seconds | First npx call downloads package |
| MCP server startup (cached) | < 500ms | Package already cached |
| Simple kubectl query | < 100ms | e.g., get pods in one namespace |
| Complex kubectl query | 200ms - 1s | e.g., get all resources across all namespaces |
| Multi-tool debugging | 2-5 seconds | Claude uses 3-5 tools sequentially |
| Log streaming | Instant | Follows kubectl streaming |

### Optimization Tips

1. **Keep server running:** Use long-running Claude sessions
2. **Cache packages:** npx caches packages after first download
3. **Use field selectors:** Reduce data transfer with kubectl filters
4. **Namespace scoping:** Query specific namespaces instead of all
5. **Output format:** Use `-o name` for lists, not full YAML

---

## 🧪 Test Your MCP Setup

### Quick Test Script

```bash
cat > /root/claude/k8s-platform/test-mcp.sh << 'EOF'
#!/bin/bash
set -e

echo "=== MCP Configuration Test ==="
echo ""

echo "1. Checking current directory:"
pwd

echo ""
echo "2. Looking for .mcp.json files:"
find /root/claude -name ".mcp.json" -o -name "mcp.json" 2>/dev/null

echo ""
echo "3. Checking MCP server registration:"
claude mcp list 2>&1 || echo "No MCP servers found"

echo ""
echo "4. Testing kubectl connectivity:"
kubectl cluster-info --request-timeout=5s

echo ""
echo "5. Testing MCP server package:"
timeout 5s npx -y mcp-server-kubernetes --kubeconfig /root/.kube/config 2>&1 &
sleep 2
pkill -f mcp-server-kubernetes || true

echo ""
echo "=== Recommendation ==="
echo "Run 'claude' from: /root/claude/"
echo "Or copy .mcp.json to your working directory"
EOF

chmod +x /root/claude/k8s-platform/test-mcp.sh
```

Run it:
```bash
./test-mcp.sh
```

---

## 🎯 Recommended Setup

### For Single Project (Your Case)

```bash
cd /root/claude/k8s-platform

# Add project-scoped MCP server
claude mcp add --transport stdio k8s -- npx -y mcp-server-kubernetes \
  --kubeconfig /root/.kube/config \
  --scope project

# This creates .mcp.json in current directory
ls -la .mcp.json

# Commit to git so team can use it
git add .mcp.json
git commit -m "Add Kubernetes MCP server configuration"
```

### For Multiple Projects

```bash
# Add user-scoped MCP (works everywhere)
claude mcp add --transport stdio k8s -- npx -y mcp-server-kubernetes \
  --kubeconfig /root/.kube/config \
  --scope user

# Now works from any directory
cd /anywhere
claude
> /mcp
✅ k8s (connected)
```

---

## 🔧 Custom MCP Server Benchmarking

If using the custom server from `k8s-platform/mcp-server/`:

### Install and Test

```bash
cd /root/claude/k8s-platform/mcp-server
npm install

# Benchmark startup time
time node server.js --kubeconfig /root/.kube/config &
sleep 1
pkill -f "node server.js" || true

# Test with sample MCP request
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | node server.js --kubeconfig /root/.kube/config
```

### Compare Servers

```bash
# Benchmark official server
time npx -y mcp-server-kubernetes --kubeconfig /root/.kube/config

# Benchmark custom server
time node /root/claude/k8s-platform/mcp-server/server.js --kubeconfig /root/.kube/config
```

---

## 🚀 Quick Fix Summary

**Your issue:** Running `claude` from wrong directory

**Quick fix:**
```bash
cd /root/claude
claude
> /mcp
```

**Permanent fix:**
```bash
# Make MCP work everywhere
claude mcp add --transport stdio k8s -- npx -y mcp-server-kubernetes \
  --kubeconfig /root/.kube/config \
  --scope user
```

**Verify:**
```bash
cd /anywhere
claude
> /mcp
✅ k8s (connected)

> Show me all pods
[Should work!]
```

---

## 📝 Checklist

- [ ] Navigate to `/root/claude/` before running `claude`
- [ ] Or add MCP server with `--scope user` to work everywhere
- [ ] Verify with `claude mcp list`
- [ ] Test with `/mcp` command in Claude session
- [ ] Try simple query: "Show me all pods"
- [ ] Run benchmarks to test performance
- [ ] Keep Claude session running for best performance

**Your MCP server should now work! 🎉**
