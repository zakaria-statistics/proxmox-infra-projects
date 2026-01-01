#!/usr/bin/env node

/**
 * Custom Kubernetes MCP Server
 * Exposes kubectl commands via Model Context Protocol for natural language cluster management
 *
 * Usage:
 *   node server.js --kubeconfig /path/to/kubeconfig
 *   npx k8s-mcp-server --kubeconfig ~/.kube/config
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { exec } from 'child_process';
import { promisify } from 'util';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const execAsync = promisify(exec);
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Parse command line arguments
const args = process.argv.slice(2);
const kubeconfigIndex = args.indexOf('--kubeconfig');
const KUBECONFIG = kubeconfigIndex !== -1 && args[kubeconfigIndex + 1]
  ? args[kubeconfigIndex + 1]
  : process.env.KUBECONFIG || `${process.env.HOME}/.kube/config`;

const KUBECTL_BIN = 'kubectl';

/**
 * Execute kubectl command with proper error handling
 */
async function runKubectl(cmdArgs) {
  const cmd = `${KUBECTL_BIN} --kubeconfig=${KUBECONFIG} ${cmdArgs}`;

  console.error(`[DEBUG] Executing: ${cmd}`);

  try {
    const { stdout, stderr } = await execAsync(cmd, {
      maxBuffer: 10 * 1024 * 1024, // 10MB buffer for large outputs
      timeout: 60000, // 60s timeout
    });

    return {
      success: true,
      stdout: stdout.trim(),
      stderr: stderr.trim(),
    };
  } catch (error) {
    return {
      success: false,
      stdout: error.stdout?.trim() || '',
      stderr: error.stderr?.trim() || error.message,
      code: error.code,
    };
  }
}

/**
 * Kubernetes MCP Server Implementation
 */
class KubernetesMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'k8s-mcp-server-custom',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();
    this.setupErrorHandling();
  }

  setupErrorHandling() {
    this.server.onerror = (error) => {
      console.error('[MCP Error]', error);
    };

    process.on('SIGINT', async () => {
      console.error('[INFO] Shutting down MCP server...');
      await this.server.close();
      process.exit(0);
    });

    process.on('uncaughtException', (error) => {
      console.error('[FATAL] Uncaught exception:', error);
      process.exit(1);
    });
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'kubectl_get',
          description: 'Get Kubernetes resources (pods, services, deployments, nodes, pv, pvc, ingress, etc.). Supports filtering by namespace, labels, and field selectors.',
          inputSchema: {
            type: 'object',
            properties: {
              resource: {
                type: 'string',
                description: 'Resource type (pods, services, deployments, nodes, pvc, pv, ingress, namespaces, events, all, etc.)',
              },
              namespace: {
                type: 'string',
                description: 'Namespace (optional, use "all" or "-A" for all namespaces)',
              },
              name: {
                type: 'string',
                description: 'Specific resource name (optional)',
              },
              output: {
                type: 'string',
                description: 'Output format: wide, yaml, json, name, custom-columns',
                enum: ['wide', 'yaml', 'json', 'name'],
              },
              selector: {
                type: 'string',
                description: 'Label selector (e.g., app=nginx, env=prod)',
              },
              fieldSelector: {
                type: 'string',
                description: 'Field selector (e.g., status.phase=Running, status.phase=Failed)',
              },
            },
            required: ['resource'],
          },
        },
        {
          name: 'kubectl_describe',
          description: 'Get detailed description of a Kubernetes resource including events, conditions, and metadata. Essential for debugging.',
          inputSchema: {
            type: 'object',
            properties: {
              resource: {
                type: 'string',
                description: 'Resource type (pod, service, deployment, node, pv, pvc, etc.)',
              },
              name: {
                type: 'string',
                description: 'Resource name',
              },
              namespace: {
                type: 'string',
                description: 'Namespace (optional for namespaced resources)',
              },
            },
            required: ['resource', 'name'],
          },
        },
        {
          name: 'kubectl_logs',
          description: 'Get container logs from a pod. Supports previous container logs, tail, and time-based filtering.',
          inputSchema: {
            type: 'object',
            properties: {
              pod: {
                type: 'string',
                description: 'Pod name',
              },
              namespace: {
                type: 'string',
                description: 'Namespace (default: default)',
              },
              container: {
                type: 'string',
                description: 'Container name (required for multi-container pods)',
              },
              previous: {
                type: 'boolean',
                description: 'Get logs from previous crashed container instance',
              },
              tail: {
                type: 'number',
                description: 'Number of lines from end of logs (e.g., 100)',
              },
              since: {
                type: 'string',
                description: 'Show logs since duration (e.g., 1h, 30m, 10s)',
              },
            },
            required: ['pod'],
          },
        },
        {
          name: 'kubectl_exec',
          description: 'Execute a command inside a running pod container. Use for debugging and inspection.',
          inputSchema: {
            type: 'object',
            properties: {
              pod: {
                type: 'string',
                description: 'Pod name',
              },
              command: {
                type: 'string',
                description: 'Command to execute (e.g., "ls /", "cat /etc/resolv.conf")',
              },
              namespace: {
                type: 'string',
                description: 'Namespace (default: default)',
              },
              container: {
                type: 'string',
                description: 'Container name (for multi-container pods)',
              },
            },
            required: ['pod', 'command'],
          },
        },
        {
          name: 'kubectl_get_events',
          description: 'Get cluster events sorted by timestamp. Critical for debugging issues - shows pod scheduling, image pulls, crashes, etc.',
          inputSchema: {
            type: 'object',
            properties: {
              namespace: {
                type: 'string',
                description: 'Namespace (use "all" or "-A" for all namespaces)',
              },
              sort: {
                type: 'boolean',
                description: 'Sort by last timestamp (default: true)',
                default: true,
              },
              tail: {
                type: 'number',
                description: 'Show only last N events',
              },
            },
          },
        },
        {
          name: 'kubectl_top',
          description: 'Get resource usage (CPU/Memory) for nodes or pods. Requires metrics-server to be installed.',
          inputSchema: {
            type: 'object',
            properties: {
              resource: {
                type: 'string',
                description: 'Resource type',
                enum: ['nodes', 'pods'],
              },
              namespace: {
                type: 'string',
                description: 'Namespace (for pods only)',
              },
              sortBy: {
                type: 'string',
                description: 'Sort by cpu or memory',
                enum: ['cpu', 'memory'],
              },
            },
            required: ['resource'],
          },
        },
        {
          name: 'kubectl_apply',
          description: 'Apply a Kubernetes manifest to create or update resources declaratively.',
          inputSchema: {
            type: 'object',
            properties: {
              manifest: {
                type: 'string',
                description: 'YAML manifest content',
              },
              namespace: {
                type: 'string',
                description: 'Namespace (optional, can be in manifest)',
              },
              dryRun: {
                type: 'boolean',
                description: 'Perform dry-run without actually applying',
              },
            },
            required: ['manifest'],
          },
        },
        {
          name: 'kubectl_delete',
          description: 'Delete a Kubernetes resource. Use with caution.',
          inputSchema: {
            type: 'object',
            properties: {
              resource: {
                type: 'string',
                description: 'Resource type (pod, service, deployment, etc.)',
              },
              name: {
                type: 'string',
                description: 'Resource name',
              },
              namespace: {
                type: 'string',
                description: 'Namespace (required for namespaced resources)',
              },
              force: {
                type: 'boolean',
                description: 'Force deletion (immediate, no grace period)',
              },
            },
            required: ['resource', 'name'],
          },
        },
        {
          name: 'kubectl_scale',
          description: 'Scale a deployment, replicaset, or statefulset to desired replica count.',
          inputSchema: {
            type: 'object',
            properties: {
              resource: {
                type: 'string',
                description: 'Resource type',
                enum: ['deployment', 'replicaset', 'statefulset'],
              },
              name: {
                type: 'string',
                description: 'Resource name',
              },
              replicas: {
                type: 'number',
                description: 'Desired number of replicas',
              },
              namespace: {
                type: 'string',
                description: 'Namespace (optional)',
              },
            },
            required: ['resource', 'name', 'replicas'],
          },
        },
        {
          name: 'kubectl_rollout',
          description: 'Manage deployment rollouts - check status, restart, undo, or view history.',
          inputSchema: {
            type: 'object',
            properties: {
              action: {
                type: 'string',
                description: 'Rollout action to perform',
                enum: ['status', 'restart', 'undo', 'history'],
              },
              resource: {
                type: 'string',
                description: 'Resource type (usually deployment)',
              },
              name: {
                type: 'string',
                description: 'Resource name',
              },
              namespace: {
                type: 'string',
                description: 'Namespace (optional)',
              },
            },
            required: ['action', 'resource', 'name'],
          },
        },
        {
          name: 'kubectl_cluster_info',
          description: 'Get cluster information including control plane endpoints and cluster status.',
          inputSchema: {
            type: 'object',
            properties: {
              dump: {
                type: 'boolean',
                description: 'Get detailed cluster dump for debugging',
              },
            },
          },
        },
        {
          name: 'kubectl_port_forward',
          description: 'Forward local port to a pod port. Returns the command to run (not executed directly).',
          inputSchema: {
            type: 'object',
            properties: {
              resource: {
                type: 'string',
                description: 'Resource type/name (e.g., pod/nginx, service/web)',
              },
              localPort: {
                type: 'number',
                description: 'Local port number',
              },
              remotePort: {
                type: 'number',
                description: 'Remote port number',
              },
              namespace: {
                type: 'string',
                description: 'Namespace (optional)',
              },
            },
            required: ['resource', 'localPort', 'remotePort'],
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        let cmdArgs = '';
        let tmpFile = null;

        switch (name) {
          case 'kubectl_get': {
            cmdArgs = `get ${args.resource}`;
            if (args.name) cmdArgs += ` ${args.name}`;
            if (args.namespace) {
              cmdArgs += args.namespace === 'all' || args.namespace === '-A'
                ? ' -A'
                : ` -n ${args.namespace}`;
            }
            if (args.output) cmdArgs += ` -o ${args.output}`;
            if (args.selector) cmdArgs += ` -l ${args.selector}`;
            if (args.fieldSelector) cmdArgs += ` --field-selector=${args.fieldSelector}`;
            break;
          }

          case 'kubectl_describe': {
            cmdArgs = `describe ${args.resource} ${args.name}`;
            if (args.namespace) cmdArgs += ` -n ${args.namespace}`;
            break;
          }

          case 'kubectl_logs': {
            cmdArgs = `logs ${args.pod}`;
            if (args.namespace) cmdArgs += ` -n ${args.namespace}`;
            if (args.container) cmdArgs += ` -c ${args.container}`;
            if (args.previous) cmdArgs += ' --previous';
            if (args.tail) cmdArgs += ` --tail=${args.tail}`;
            if (args.since) cmdArgs += ` --since=${args.since}`;
            break;
          }

          case 'kubectl_exec': {
            cmdArgs = `exec ${args.pod}`;
            if (args.namespace) cmdArgs += ` -n ${args.namespace}`;
            if (args.container) cmdArgs += ` -c ${args.container}`;
            cmdArgs += ` -- ${args.command}`;
            break;
          }

          case 'kubectl_get_events': {
            cmdArgs = 'get events';
            if (args.namespace) {
              cmdArgs += args.namespace === 'all' || args.namespace === '-A'
                ? ' -A'
                : ` -n ${args.namespace}`;
            }
            if (args.sort) {
              cmdArgs += " --sort-by='.lastTimestamp'";
            }
            break;
          }

          case 'kubectl_top': {
            cmdArgs = `top ${args.resource}`;
            if (args.resource === 'pods' && args.namespace) {
              cmdArgs += ` -n ${args.namespace}`;
            }
            if (args.sortBy) {
              cmdArgs += ` --sort-by=${args.sortBy}`;
            }
            break;
          }

          case 'kubectl_apply': {
            // Write manifest to temp file
            tmpFile = `/tmp/k8s-manifest-${Date.now()}.yaml`;
            const escapedManifest = args.manifest.replace(/'/g, "'\\''");
            await execAsync(`echo '${escapedManifest}' > ${tmpFile}`);

            cmdArgs = `apply -f ${tmpFile}`;
            if (args.namespace) cmdArgs += ` -n ${args.namespace}`;
            if (args.dryRun) cmdArgs += ' --dry-run=client';
            break;
          }

          case 'kubectl_delete': {
            cmdArgs = `delete ${args.resource} ${args.name}`;
            if (args.namespace) cmdArgs += ` -n ${args.namespace}`;
            if (args.force) cmdArgs += ' --force --grace-period=0';
            break;
          }

          case 'kubectl_scale': {
            cmdArgs = `scale ${args.resource} ${args.name} --replicas=${args.replicas}`;
            if (args.namespace) cmdArgs += ` -n ${args.namespace}`;
            break;
          }

          case 'kubectl_rollout': {
            cmdArgs = `rollout ${args.action} ${args.resource}/${args.name}`;
            if (args.namespace) cmdArgs += ` -n ${args.namespace}`;
            break;
          }

          case 'kubectl_cluster_info': {
            cmdArgs = 'cluster-info';
            if (args.dump) cmdArgs += ' dump';
            break;
          }

          case 'kubectl_port_forward': {
            // Don't actually run port-forward (it blocks), just return the command
            let cmd = `kubectl port-forward ${args.resource} ${args.localPort}:${args.remotePort}`;
            if (args.namespace) cmd += ` -n ${args.namespace}`;

            return {
              content: [
                {
                  type: 'text',
                  text: `Port forward command (run this manually in a terminal):\n${cmd}`,
                },
              ],
            };
          }

          default:
            throw new Error(`Unknown tool: ${name}`);
        }

        const result = await runKubectl(cmdArgs);

        // Clean up temp file if created
        if (tmpFile) {
          try {
            await execAsync(`rm -f ${tmpFile}`);
          } catch (e) {
            console.error('[WARN] Failed to clean up temp file:', tmpFile);
          }
        }

        // Format response
        const output = result.success
          ? result.stdout || result.stderr || 'Command executed successfully'
          : `Error: ${result.stderr || 'Unknown error'}\nExit code: ${result.code || 'N/A'}`;

        return {
          content: [
            {
              type: 'text',
              text: output,
            },
          ],
          isError: !result.success,
        };
      } catch (error) {
        console.error('[ERROR] Tool execution failed:', error);
        return {
          content: [
            {
              type: 'text',
              text: `Error executing kubectl command: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error(`Kubernetes MCP Server v1.0.0 running`);
    console.error(`Using kubeconfig: ${KUBECONFIG}`);
    console.error(`Ready to handle MCP tool requests...`);
  }
}

// Start server
const server = new KubernetesMCPServer();
server.run().catch((error) => {
  console.error('[FATAL] Failed to start server:', error);
  process.exit(1);
});
