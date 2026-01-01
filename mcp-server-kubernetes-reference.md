# MCP Server Kubernetes - Operations Reference

Official package: `mcp-server-kubernetes` (Flux159)
Configuration: `/root/claude/.mcp.json`

---

## 📋 kubectl Operations (11 tools)

### `kubectl_get`
**Purpose:** Retrieve or list Kubernetes resources
**Use cases:**
- List all pods: `resource: "pods"`, `namespace: "default"`
- Get all nodes: `resource: "nodes"`
- List services across all namespaces: `resource: "services"`, `namespace: "all"`
- Get specific deployment: `resource: "deployment"`, `name: "nginx"`, `namespace: "default"`

**Parameters:**
- `resource` (required): pods, nodes, services, deployments, pv, pvc, ingress, namespaces, etc.
- `namespace` (optional): namespace name or "all" for all namespaces
- `name` (optional): specific resource name
- `output` (optional): wide, yaml, json

---

### `kubectl_describe`
**Purpose:** Get detailed information about a resource
**Use cases:**
- Debug pod issues: see events, conditions, volume mounts
- Check node capacity and allocations
- View service endpoints

**Parameters:**
- `resource` (required): pod, node, service, deployment, etc.
- `name` (required): resource name
- `namespace` (optional): namespace for namespaced resources

---

### `kubectl_create`
**Purpose:** Create new Kubernetes resources
**Use cases:**
- Create namespace
- Create configmap from literal values
- Create secret

**Parameters:**
- `resource_type` (required): namespace, configmap, secret, etc.
- `name` (required): resource name
- Additional parameters vary by resource type

---

### `kubectl_apply`
**Purpose:** Apply YAML manifests declaratively
**Use cases:**
- Deploy applications
- Update existing resources
- Apply multiple resources from YAML

**Parameters:**
- `manifest` (required): YAML content
- `namespace` (optional): target namespace
- `filename` (optional): path to YAML file

---

### `kubectl_delete`
**Purpose:** Remove Kubernetes resources
**Use cases:**
- Delete failed pods
- Remove old deployments
- Clean up resources

**Parameters:**
- `resource` (required): resource type
- `name` (required): resource name
- `namespace` (optional): namespace
- `force` (optional): immediate deletion without grace period

⚠️ **Caution:** Deletion is permanent. Use non-destructive mode to prevent accidents.

---

### `kubectl_logs`
**Purpose:** Access container logs from pods
**Use cases:**
- Debug application errors
- Monitor application output
- Check crash logs from previous container

**Parameters:**
- `pod` (required): pod name
- `namespace` (optional): default is "default"
- `container` (optional): container name for multi-container pods
- `previous` (optional): get logs from crashed container
- `tail` (optional): number of lines from end
- `since` (optional): show logs since duration (e.g., "1h", "30m")

---

### `kubectl_context`
**Purpose:** Manage kubectl contexts (cluster/user combinations)
**Use cases:**
- Switch between clusters
- List available contexts
- Set default context

**Parameters:**
- `action` (required): get-contexts, current-context, use-context
- `context` (optional): context name to switch to

---

### `kubectl_scale`
**Purpose:** Adjust replica counts for deployments/replicasets/statefulsets
**Use cases:**
- Scale up for traffic
- Scale down to save resources
- Set replicas to 0 for maintenance

**Parameters:**
- `resource` (required): deployment, replicaset, statefulset
- `name` (required): resource name
- `replicas` (required): desired count
- `namespace` (optional): namespace

---

### `kubectl_patch`
**Purpose:** Update specific fields of a resource
**Use cases:**
- Update image version
- Modify environment variables
- Change resource limits

**Parameters:**
- `resource` (required): resource type
- `name` (required): resource name
- `patch` (required): JSON patch data
- `namespace` (optional): namespace

---

### `kubectl_rollout`
**Purpose:** Manage deployment rollouts
**Use cases:**
- Check rollout status
- Restart deployment (recreate pods)
- Undo last rollout
- View rollout history

**Parameters:**
- `action` (required): status, restart, undo, history, pause, resume
- `resource` (required): deployment, daemonset, statefulset
- `name` (required): resource name
- `namespace` (optional): namespace

---

### `kubectl_generic`
**Purpose:** Execute arbitrary kubectl commands
**Use cases:**
- Run complex kubectl commands not covered by other tools
- Use advanced flags and options
- Custom queries and filters

**Parameters:**
- `command` (required): full kubectl command (without "kubectl" prefix)

**Example:** `command: "get pods -A --field-selector=status.phase=Running"`

---

## 🎯 Helm Operations (5 tools)

### `install_helm_chart`
**Purpose:** Deploy Helm charts
**Use cases:**
- Install applications from Helm repositories
- Deploy with custom values
- Install specific chart versions

**Parameters:**
- `release_name` (required): name for the release
- `chart` (required): chart name or path
- `namespace` (optional): target namespace
- `values` (optional): custom values (YAML)
- `repo` (optional): Helm repository URL
- `version` (optional): chart version

---

### `upgrade_helm_chart`
**Purpose:** Update existing Helm releases
**Use cases:**
- Update application version
- Change configuration values
- Roll forward after testing

**Parameters:**
- `release_name` (required): existing release name
- `chart` (required): chart name or path
- `namespace` (optional): namespace
- `values` (optional): updated values
- `reuse_values` (optional): keep existing values

---

### `helm_template_apply`
**Purpose:** Template-based installation (bypasses Tiller/auth issues)
**Use cases:**
- Install when direct Helm install fails
- Preview rendered manifests before applying
- GitOps workflows

**Parameters:**
- `release_name` (required): release name
- `chart` (required): chart name or path
- `namespace` (optional): namespace
- `values` (optional): custom values

---

### `helm_template_uninstall`
**Purpose:** Template-based removal
**Use cases:**
- Remove resources installed via helm_template_apply
- Clean uninstall when Helm tracking is lost

**Parameters:**
- `release_name` (required): release name
- `chart` (required): chart name or path
- `namespace` (optional): namespace

---

### `uninstall_helm_chart`
**Purpose:** Remove Helm releases
**Use cases:**
- Uninstall applications
- Clean up test deployments
- Remove charts completely

**Parameters:**
- `release_name` (required): release name
- `namespace` (optional): namespace
- `keep_history` (optional): retain release history

---

## 🔧 Cluster Management (5 tools)

### `cleanup_pods`
**Purpose:** Auto-remove problematic pods
**Use cases:**
- Clean up after failed deployments
- Remove evicted pods
- Clear crash loop pods for fresh restart

**Removes pods in these states:**
- Evicted
- ContainerStatusUnknown
- Completed (jobs)
- Error
- ImagePullBackOff
- CrashLoopBackOff

**Parameters:**
- `namespace` (optional): target namespace or "all"
- `states` (optional): specific states to clean (defaults to all)

---

### `node_management`
**Purpose:** Cordon, drain, and uncordon nodes
**Use cases:**
- Prepare node for maintenance
- Safely evict pods from node
- Return node to service

**Operations:**
- `cordon` - Mark node unschedulable (no new pods)
- `drain` - Evict all pods from node
- `uncordon` - Mark node schedulable again

**Parameters:**
- `action` (required): cordon, drain, uncordon
- `node` (required): node name
- `force` (optional): force drain
- `ignore_daemonsets` (optional): skip DaemonSet pods

---

### `port_forward`
**Purpose:** Establish port forwarding to pods/services
**Use cases:**
- Access pod directly for debugging
- Connect to service without LoadBalancer
- Database access for development

**Parameters:**
- `resource` (required): pod/name or service/name
- `local_port` (required): local port number
- `remote_port` (required): container/service port
- `namespace` (optional): namespace

**Example:** Forward local 8080 to pod's 80:
`resource: "pod/nginx"`, `local_port: 8080`, `remote_port: 80`

---

### `stop_port_forward`
**Purpose:** Terminate active port forwarding sessions
**Use cases:**
- Clean up after debugging
- Stop all forwarding sessions

**Parameters:**
- `resource` (optional): specific resource to stop (stops all if omitted)

---

### `ping`
**Purpose:** Verify cluster connectivity
**Use cases:**
- Test cluster access
- Validate kubeconfig
- Check API server status

**Parameters:** None

---

## 📚 Info/Diagnostics (3 tools)

### `explain_resource`
**Purpose:** Get documentation for Kubernetes resource types
**Use cases:**
- Learn resource field structure
- Understand nested fields
- API version information

**Parameters:**
- `resource` (required): resource type (e.g., "pod", "deployment.spec")
- `recursive` (optional): show all nested fields

**Example:** `resource: "pod.spec.containers"` shows container field documentation

---

### `list_api_resources`
**Purpose:** Display available API resources in cluster
**Use cases:**
- Discover available resources
- Check API versions
- See if CRDs are installed

**Parameters:**
- `namespaced` (optional): filter namespaced resources only
- `api_group` (optional): filter by API group

---

### `/k8s-diagnose` (Prompt)
**Purpose:** Guided troubleshooting workflow
**Use cases:**
- Systematic pod debugging
- Follow best-practice diagnostic flow
- Learn troubleshooting methodology

**Process:**
1. Search pods by keyword
2. Check pod status and events
3. Examine logs
4. Inspect configuration
5. Suggest fixes

**Parameters:**
- `keyword` (required): search term for pod name
- `namespace` (optional): target namespace

---

## 🔒 Security Features

### Secrets Masking
Automatically redacts sensitive data in:
- Secret values
- ConfigMap data marked as sensitive
- Environment variables with keywords: password, token, key, secret

### Non-Destructive Mode
When enabled:
- ✅ Allows: get, describe, logs, explain, list operations
- ✅ Allows: create, apply, update operations
- ❌ Blocks: delete, drain operations
- ❌ Blocks: destructive patches

**Enable in MCP config:**
```json
{
  "command": "npx",
  "args": ["-y", "mcp-server-kubernetes", "--non-destructive"]
}
```

---

## 🆚 Comparison with Custom MCP

| Feature | Official MCP | Custom MCP (/k8s-platform/mcp-server/) |
|---------|-------------|----------------------------------------|
| kubectl operations | 11 tools | 12 tools |
| Helm support | ✅ 5 tools | ❌ None |
| Cluster management | ✅ Advanced | ❌ Basic |
| Diagnostics | ✅ Guided prompt | ❌ Manual |
| Security features | ✅ Masking + modes | ❌ None |
| Maintenance | Auto-updates | Self-maintained |
| Port forwarding | ✅ Managed sessions | ⚠️ Returns command only |

**Recommendation:**
- **Production/Learning:** Use official MCP (more features, safer, auto-updates)
- **Custom needs:** Use custom MCP only if you need specific modifications

---

## 📖 Usage Examples

### Example 1: Debug Failing Pod
```
1. Use kubectl_get to list pods
   - resource: "pods"
   - namespace: "default"

2. Use kubectl_describe to see events
   - resource: "pod"
   - name: "my-app-xyz"
   - namespace: "default"

3. Use kubectl_logs to check output
   - pod: "my-app-xyz"
   - namespace: "default"
   - tail: 100
```

### Example 2: Deploy Application
```
1. Use kubectl_apply with YAML manifest
   - manifest: "[YAML content]"
   - namespace: "production"

2. Use kubectl_rollout to check status
   - action: "status"
   - resource: "deployment"
   - name: "my-app"

3. Use kubectl_get to verify pods
   - resource: "pods"
   - namespace: "production"
   - selector: "app=my-app"
```

### Example 3: Scale Application
```
1. Use kubectl_scale
   - resource: "deployment"
   - name: "web-server"
   - replicas: 5
   - namespace: "default"

2. Use kubectl_rollout to watch
   - action: "status"
   - resource: "deployment"
   - name: "web-server"
```

### Example 4: Node Maintenance
```
1. Use kubectl_get to list nodes
   - resource: "nodes"

2. Use node_management to cordon
   - action: "cordon"
   - node: "worker-1"

3. Use node_management to drain
   - action: "drain"
   - node: "worker-1"
   - ignore_daemonsets: true

4. [Perform maintenance]

5. Use node_management to uncordon
   - action: "uncordon"
   - node: "worker-1"
```

---

## 🔗 Resources

- **GitHub:** https://github.com/Flux159/mcp-server-kubernetes
- **NPM:** https://www.npmjs.com/package/mcp-server-kubernetes
- **MCP Config:** `/root/claude/.mcp.json`
- **Kubeconfig:** `/root/.kube/config`

---

## 🚀 Quick Start Commands

Ask Claude:
```
"Show all nodes in the cluster"
"List pods in all namespaces"
"Describe the nginx deployment"
"Scale web-server to 3 replicas"
"Show logs from my-app pod, last 50 lines"
"Install nginx ingress controller using Helm"
"Clean up failed pods in default namespace"
"Diagnose issues with the database pod"
```

Claude will use the appropriate MCP tools automatically.
