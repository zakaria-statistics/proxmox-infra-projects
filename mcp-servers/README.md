# MCP Servers - Multi-Ecosystem Learning Project

## Purpose
Learn MCP (Model Context Protocol) by building custom servers for different infrastructure ecosystems.

## Structure
```
mcp-servers/
├── k8s-mcp/         # Kubernetes cluster management
├── docker-mcp/      # Docker container operations
├── security-mcp/    # Security scanning & monitoring
└── proxmox-mcp/     # Proxmox VM/container management
```

## Learning Path

### Phase 1: Understand MCP Basics
- [ ] Read MCP specification
- [ ] Study the custom k8s-mcp in k8s-platform/mcp-server/
- [ ] Understand Resources vs Tools in MCP

### Phase 2: Migrate & Enhance K8s MCP
- [ ] Copy custom k8s MCP to mcp-servers/k8s-mcp/
- [ ] Add more advanced kubectl operations
- [ ] Test integration with Claude

### Phase 3: Build Docker MCP
- [ ] List/inspect containers
- [ ] View logs, stats
- [ ] Execute commands in containers
- [ ] Compose operations

### Phase 4: Build Security MCP
- [ ] Vulnerability scanning (trivy)
- [ ] Security policy checks
- [ ] Audit log analysis
- [ ] Compliance checks

### Phase 5: Build Proxmox MCP
- [ ] VM/CT operations
- [ ] Resource monitoring
- [ ] Network management
- [ ] Storage operations

## Integration
Once built, add to project-specific .mcp.json configs:
- k8s-platform → k8s-mcp
- cicd-platform → docker-mcp, k8s-mcp
- security-lab → security-mcp, k8s-mcp
- All projects → proxmox-mcp (underlying infrastructure)

## Resources
- MCP Spec: https://spec.modelcontextprotocol.io/
- MCP SDK: https://github.com/modelcontextprotocol/sdk
- Example: /root/claude/k8s-platform/mcp-server/
