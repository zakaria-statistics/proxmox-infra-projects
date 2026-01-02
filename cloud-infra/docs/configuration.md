# Cloud Configuration with Ansible

**Purpose:** Configure provisioned cloud resources (install add-ons, set up monitoring, apply security policies)

## Terraform vs Ansible

**Clear Separation of Concerns:**

```
Terraform (Provisioning)              Ansible (Configuration)
────────────────────────              ───────────────────────
• Create VPC/VNet/Network             • Install Ingress Controller
• Provision K8s cluster               • Install Metrics Server
• Create VMs/node pools               • Deploy Prometheus/Grafana
• Set up load balancers               • Configure cluster autoscaler
• Network routing, firewalls          • Apply network policies
                                      • Install Helm charts
                                      • OS-level configuration

What infrastructure exists       →    How infrastructure behaves
```

**Why not just Terraform?**
- Terraform creates resources, Ansible configures them
- Ansible is better for:
  - Sequential operations (install A, then B)
  - Templating config files
  - OS package management
  - Application deployment workflows

**Why not just kubectl?**
- Ansible orchestrates multiple kubectl operations
- Handles dependencies (install metrics-server before HPA)
- Reusable playbooks across environments
- Integrates with OS-level tasks

---

## Ansible Basics

### Installation

```bash
# macOS
brew install ansible

# Linux
sudo apt install ansible

# Verify
ansible --version
```

### Core Concepts

**Inventory:** What hosts/clusters to configure
```ini
# inventory/azure.ini
[aks_clusters]
aks-cluster-01 kubeconfig=/Users/me/.kube/aks-config

[eks_clusters]
eks-cluster-01 kubeconfig=/Users/me/.kube/eks-config

[all_clusters:children]
aks_clusters
eks_clusters
```

**Playbook:** What tasks to run
```yaml
# playbooks/install-metrics-server.yml
- name: Install Metrics Server on K8s cluster
  hosts: all_clusters
  tasks:
    - name: Apply Metrics Server manifest
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        src: "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
```

**Workflow:**
```bash
# Run playbook against inventory
ansible-playbook -i inventory/azure.ini playbooks/install-metrics-server.yml
```

---

## Common Configuration Tasks

### 1. Install Metrics Server

**Why:** Required for `kubectl top` and Horizontal Pod Autoscaler (HPA)

**playbooks/install-metrics-server.yml:**
```yaml
---
- name: Install Metrics Server
  hosts: "{{ target_cluster | default('all_clusters') }}"
  gather_facts: no

  tasks:
    - name: Download Metrics Server manifest
      ansible.builtin.get_url:
        url: https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        dest: /tmp/metrics-server.yaml

    - name: Apply Metrics Server
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        src: /tmp/metrics-server.yaml

    - name: Wait for Metrics Server to be ready
      kubernetes.core.k8s_info:
        kubeconfig: "{{ kubeconfig }}"
        kind: Deployment
        namespace: kube-system
        name: metrics-server
        wait: yes
        wait_timeout: 300

    - name: Verify Metrics Server
      ansible.builtin.command:
        cmd: kubectl --kubeconfig={{ kubeconfig }} top nodes
      register: metrics_output
      retries: 5
      delay: 10
      until: metrics_output.rc == 0

    - name: Show node metrics
      ansible.builtin.debug:
        var: metrics_output.stdout_lines
```

**Usage:**
```bash
ansible-playbook -i inventory/azure.ini playbooks/install-metrics-server.yml
```

---

### 2. Install Ingress Controller

**playbooks/install-ingress-nginx.yml:**
```yaml
---
- name: Install Nginx Ingress Controller
  hosts: "{{ target_cluster | default('all_clusters') }}"
  gather_facts: no

  vars:
    ingress_namespace: ingress-nginx
    ingress_version: v1.9.5

  tasks:
    - name: Create namespace
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        definition:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: "{{ ingress_namespace }}"

    - name: Install Nginx Ingress via Helm
      kubernetes.core.helm:
        kubeconfig: "{{ kubeconfig }}"
        name: ingress-nginx
        chart_ref: ingress-nginx/ingress-nginx
        release_namespace: "{{ ingress_namespace }}"
        create_namespace: yes
        values:
          controller:
            replicaCount: 2
            service:
              type: LoadBalancer  # Gets cloud LB on AKS/EKS/GKE
            metrics:
              enabled: true

    - name: Wait for Ingress Controller
      kubernetes.core.k8s_info:
        kubeconfig: "{{ kubeconfig }}"
        kind: Service
        namespace: "{{ ingress_namespace }}"
        name: ingress-nginx-controller
        wait: yes
        wait_timeout: 300

    - name: Get LoadBalancer IP
      kubernetes.core.k8s_info:
        kubeconfig: "{{ kubeconfig }}"
        kind: Service
        namespace: "{{ ingress_namespace }}"
        name: ingress-nginx-controller
      register: ingress_svc

    - name: Show Ingress external IP
      ansible.builtin.debug:
        msg: "Ingress external IP: {{ ingress_svc.resources[0].status.loadBalancer.ingress[0].ip }}"
```

---

### 3. Install Monitoring Stack (Prometheus + Grafana)

**playbooks/install-monitoring.yml:**
```yaml
---
- name: Install Prometheus and Grafana
  hosts: "{{ target_cluster | default('all_clusters') }}"
  gather_facts: no

  vars:
    monitoring_namespace: monitoring

  tasks:
    - name: Add Prometheus Helm repo
      kubernetes.core.helm_repository:
        name: prometheus-community
        repo_url: https://prometheus-community.github.io/helm-charts

    - name: Install kube-prometheus-stack
      kubernetes.core.helm:
        kubeconfig: "{{ kubeconfig }}"
        name: prometheus
        chart_ref: prometheus-community/kube-prometheus-stack
        release_namespace: "{{ monitoring_namespace }}"
        create_namespace: yes
        values:
          prometheus:
            prometheusSpec:
              retention: 30d
              storageSpec:
                volumeClaimTemplate:
                  spec:
                    accessModes: ["ReadWriteOnce"]
                    resources:
                      requests:
                        storage: 50Gi
          grafana:
            adminPassword: "{{ grafana_password | default('admin') }}"
            service:
              type: LoadBalancer  # Or use Ingress

    - name: Wait for Prometheus to be ready
      kubernetes.core.k8s_info:
        kubeconfig: "{{ kubeconfig }}"
        kind: StatefulSet
        namespace: "{{ monitoring_namespace }}"
        name: prometheus-prometheus-kube-prometheus-prometheus
        wait: yes
        wait_timeout: 600

    - name: Get Grafana LoadBalancer IP
      kubernetes.core.k8s_info:
        kubeconfig: "{{ kubeconfig }}"
        kind: Service
        namespace: "{{ monitoring_namespace }}"
        name: prometheus-grafana
      register: grafana_svc

    - name: Show Grafana access info
      ansible.builtin.debug:
        msg: |
          Grafana URL: http://{{ grafana_svc.resources[0].status.loadBalancer.ingress[0].ip }}
          Username: admin
          Password: {{ grafana_password | default('admin') }}
```

---

### 4. Cloud-Specific Configuration

#### Azure AKS

**playbooks/configure-aks.yml:**
```yaml
---
- name: Configure AKS-specific features
  hosts: aks_clusters
  gather_facts: no

  tasks:
    - name: Enable Azure AD Workload Identity
      ansible.builtin.command:
        cmd: >
          az aks update
          --resource-group {{ resource_group }}
          --name {{ cluster_name }}
          --enable-oidc-issuer
          --enable-workload-identity

    - name: Install Azure Workload Identity webhook
      kubernetes.core.helm:
        kubeconfig: "{{ kubeconfig }}"
        name: workload-identity-webhook
        chart_ref: azure-workload-identity/workload-identity-webhook
        release_namespace: azure-workload-identity-system
        create_namespace: yes

    - name: Install Azure Key Vault CSI driver
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        src: https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/deployment/provider-azure-installer.yaml
```

#### AWS EKS

**playbooks/configure-eks.yml:**
```yaml
---
- name: Configure EKS-specific features
  hosts: eks_clusters
  gather_facts: no

  tasks:
    - name: Install AWS Load Balancer Controller
      block:
        - name: Create IAM policy for ALB controller
          ansible.builtin.command:
            cmd: >
              aws iam create-policy
              --policy-name AWSLoadBalancerControllerIAMPolicy
              --policy-document file://alb-iam-policy.json
          ignore_errors: yes

        - name: Create service account with IRSA
          ansible.builtin.command:
            cmd: >
              eksctl create iamserviceaccount
              --cluster={{ cluster_name }}
              --namespace=kube-system
              --name=aws-load-balancer-controller
              --attach-policy-arn=arn:aws:iam::{{ aws_account_id }}:policy/AWSLoadBalancerControllerIAMPolicy
              --approve

        - name: Install ALB controller via Helm
          kubernetes.core.helm:
            kubeconfig: "{{ kubeconfig }}"
            name: aws-load-balancer-controller
            chart_ref: eks/aws-load-balancer-controller
            release_namespace: kube-system
            values:
              clusterName: "{{ cluster_name }}"
              serviceAccount:
                create: false
                name: aws-load-balancer-controller

    - name: Install EBS CSI Driver
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        definition:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: aws-ebs-csi-driver
```

#### GCP GKE

**playbooks/configure-gke.yml:**
```yaml
---
- name: Configure GKE-specific features
  hosts: gke_clusters
  gather_facts: no

  tasks:
    - name: Enable Workload Identity
      ansible.builtin.command:
        cmd: >
          gcloud container clusters update {{ cluster_name }}
          --region={{ region }}
          --workload-pool={{ project_id }}.svc.id.goog

    - name: Install Config Connector (manage GCP resources from K8s)
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        src: https://raw.githubusercontent.com/GoogleCloudPlatform/k8s-config-connector/master/install-bundles/install-bundle-workload-identity/0-cnrm-system.yaml
```

---

### 5. Security Configuration

**playbooks/apply-security-policies.yml:**
```yaml
---
- name: Apply security policies
  hosts: all_clusters
  gather_facts: no

  tasks:
    - name: Install Calico network policies (if not using cloud CNI)
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        src: https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml
      when: install_calico | default(false)

    - name: Create default deny-all NetworkPolicy
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        definition:
          apiVersion: networking.k8s.io/v1
          kind: NetworkPolicy
          metadata:
            name: default-deny-all
            namespace: default
          spec:
            podSelector: {}
            policyTypes:
            - Ingress
            - Egress

    - name: Install Pod Security Standards
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        definition:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: production
            labels:
              pod-security.kubernetes.io/enforce: restricted
              pod-security.kubernetes.io/audit: restricted
              pod-security.kubernetes.io/warn: restricted

    - name: Install Trivy Operator (vulnerability scanning)
      kubernetes.core.helm:
        kubeconfig: "{{ kubeconfig }}"
        name: trivy-operator
        chart_ref: aquasecurity/trivy-operator
        release_namespace: trivy-system
        create_namespace: yes
```

---

## Complete Cluster Bootstrap Playbook

**playbooks/bootstrap-cluster.yml:**
```yaml
---
- name: Bootstrap Kubernetes cluster (all add-ons)
  hosts: "{{ target_cluster }}"
  gather_facts: no

  vars:
    monitoring_namespace: monitoring
    ingress_namespace: ingress-nginx

  pre_tasks:
    - name: Verify cluster connectivity
      kubernetes.core.k8s_info:
        kubeconfig: "{{ kubeconfig }}"
        kind: Node
      register: nodes

    - name: Show cluster info
      ansible.builtin.debug:
        msg: "Cluster has {{ nodes.resources | length }} nodes"

  tasks:
    # 1. Core cluster components
    - name: Install Metrics Server
      ansible.builtin.import_tasks: tasks/install-metrics-server.yml

    - name: Install Ingress Controller
      ansible.builtin.import_tasks: tasks/install-ingress-nginx.yml

    # 2. Storage
    - name: Configure storage classes
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        definition: "{{ lookup('file', 'manifests/storageclass-{{ cloud_provider }}.yaml') | from_yaml }}"

    # 3. Monitoring
    - name: Install Prometheus and Grafana
      ansible.builtin.import_tasks: tasks/install-monitoring.yml

    # 4. Security
    - name: Apply security policies
      ansible.builtin.import_tasks: tasks/apply-security-policies.yml

    # 5. Cloud-specific
    - name: Configure cloud-specific features
      ansible.builtin.include_tasks: "tasks/configure-{{ cloud_provider }}.yml"

  post_tasks:
    - name: Verify all components
      kubernetes.core.k8s_info:
        kubeconfig: "{{ kubeconfig }}"
        kind: Pod
        namespace: "{{ item }}"
      loop:
        - kube-system
        - "{{ monitoring_namespace }}"
        - "{{ ingress_namespace }}"
      register: pods

    - name: Show summary
      ansible.builtin.debug:
        msg: "Cluster bootstrapped successfully!"
```

**Usage:**
```bash
# Bootstrap AKS cluster
ansible-playbook -i inventory/azure.ini playbooks/bootstrap-cluster.yml \
  -e target_cluster=aks-cluster-01 \
  -e cloud_provider=azure

# Bootstrap EKS cluster
ansible-playbook -i inventory/aws.ini playbooks/bootstrap-cluster.yml \
  -e target_cluster=eks-cluster-01 \
  -e cloud_provider=aws

# Bootstrap all clusters
ansible-playbook -i inventory/all.ini playbooks/bootstrap-cluster.yml \
  -e target_cluster=all_clusters
```

---

## Inventory Organization

**inventory/group_vars/all.yml:**
```yaml
---
# Global variables for all clusters

# Versions
metrics_server_version: v0.6.4
ingress_nginx_version: v1.9.5
prometheus_stack_version: 51.2.0

# Monitoring
grafana_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  # Encrypted with ansible-vault

# Namespaces
monitoring_namespace: monitoring
ingress_namespace: ingress-nginx
security_namespace: security
```

**inventory/group_vars/aks_clusters.yml:**
```yaml
---
cloud_provider: azure
resource_group: rg-k8s-prod
```

**inventory/group_vars/eks_clusters.yml:**
```yaml
---
cloud_provider: aws
region: us-east-1
aws_account_id: "123456789012"
```

---

## Integration with Terraform

**Option 1: Terraform outputs → Ansible inventory**

```bash
# After terraform apply
terraform output -json > /tmp/terraform-outputs.json

# Generate Ansible inventory from Terraform outputs
python3 scripts/terraform-to-inventory.py /tmp/terraform-outputs.json > inventory/auto-generated.ini

# Run Ansible
ansible-playbook -i inventory/auto-generated.ini playbooks/bootstrap-cluster.yml
```

**Option 2: Terraform local-exec provisioner (automatic)**

```hcl
# terraform/main.tf
resource "azurerm_kubernetes_cluster" "aks" {
  # ... cluster definition

  provisioner "local-exec" {
    command = <<-EOT
      # Get kubeconfig
      az aks get-credentials --resource-group ${self.resource_group_name} --name ${self.name}

      # Run Ansible bootstrap
      ansible-playbook -i inventory/azure.ini playbooks/bootstrap-cluster.yml \
        -e target_cluster=${self.name} \
        -e cloud_provider=azure
    EOT
  }
}
```

---

## Best Practices

### 1. Idempotency
```yaml
# Ansible should be safe to run multiple times
# Use state: present (not commands that fail if already exists)
- name: Create namespace
  kubernetes.core.k8s:
    state: present  # Safe to rerun
    definition:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: my-namespace
```

### 2. Wait for Resources
```yaml
- name: Install Helm chart
  kubernetes.core.helm:
    # ...

- name: Wait for deployment
  kubernetes.core.k8s_info:
    kind: Deployment
    namespace: my-namespace
    name: my-app
    wait: yes
    wait_timeout: 300  # Don't proceed until ready
```

### 3. Use Ansible Vault for Secrets
```bash
# Encrypt sensitive values
ansible-vault encrypt_string 'my-secret-password' --name 'grafana_password'

# Run playbook with vault password
ansible-playbook playbook.yml --ask-vault-pass
```

### 4. Tag Tasks
```yaml
- name: Install Metrics Server
  tags: [metrics, core]
  # ...

- name: Install Prometheus
  tags: [monitoring]
  # ...

# Run only monitoring tasks
ansible-playbook playbook.yml --tags monitoring
```

### 5. Check Mode (Dry Run)
```bash
# Preview changes without applying
ansible-playbook playbook.yml --check
```

---

## Ansible vs kubectl vs Helm

| Task | Best Tool | Why |
|------|-----------|-----|
| Install single manifest | kubectl | Simple, direct |
| Install complex app (many manifests) | Helm | Package manager, versioned releases |
| Install multiple apps in sequence | Ansible | Orchestration, dependencies |
| Configure OS-level (VMs) | Ansible | SSH access, package management |
| Cloud-specific operations | Ansible | Integrates az/aws/gcloud CLIs |
| Hybrid workflows (IaC + config) | Ansible | Unified automation |

**Example workflow:**
```
1. Terraform: Provision AKS cluster
2. Ansible: Bootstrap cluster (metrics, ingress, monitoring)
3. kubectl: Deploy test application (native learning)
4. GitOps: Automate deployments (later, after mastering native)
```

---

## Next Steps

After configuring with Ansible:
1. Cluster is ready with all add-ons installed
2. Deploy applications using native kubectl (see `gitops.md` for native approach)
3. Later: Automate deployments with ArgoCD/Flux (after mastering kubectl)

---

*Last Updated: 2026-01-02*
