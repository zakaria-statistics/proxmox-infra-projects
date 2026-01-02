# Cloud Provisioning with Terraform

**Purpose:** Infrastructure as Code (IaC) for provisioning cloud resources

## Why Terraform for Provisioning?

### Declarative vs Imperative

**Imperative (CLI commands):**
```bash
# Must run in order, hard to track state
az group create --name rg-k8s --location eastus
az aks create --resource-group rg-k8s --name aks-cluster ...
az network vnet create ...
# If one fails, manual cleanup needed
```

**Declarative (Terraform):**
```hcl
# Describe desired state, Terraform figures out how to get there
resource "azurerm_resource_group" "rg" {
  name     = "rg-k8s"
  location = "eastus"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-cluster"
  resource_group_name = azurerm_resource_group.rg.name
  # Terraform handles dependencies automatically
}
```

### Benefits

1. **Version Control:** Infrastructure in Git, track changes over time
2. **Repeatability:** `terraform apply` creates identical environments
3. **State Management:** Knows what exists, only creates/updates what changed
4. **Multi-Cloud:** Same tool for Azure, AWS, GCP
5. **Modularity:** Reusable modules (DRY principle)
6. **Plan Before Apply:** Preview changes before making them

---

## Terraform Basics

### Installation

```bash
# macOS
brew install terraform

# Linux
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt install terraform

# Verify
terraform version
```

### Workflow

```
terraform init     # Download providers (azurerm, aws, google)
      ↓
terraform plan     # Preview changes (dry-run)
      ↓
terraform apply    # Execute changes
      ↓
terraform destroy  # Cleanup resources (dev environments)
```

### State File

**Critical Concept:** `terraform.tfstate` tracks what exists

```bash
# Local state (development)
terraform.tfstate  # DO NOT commit to Git (contains secrets)

# Remote state (production)
# Store in Azure Storage / AWS S3 / Terraform Cloud
terraform {
  backend "azurerm" {
    storage_account_name = "tfstate"
    container_name       = "tfstate"
    key                  = "aks-prod.tfstate"
  }
}
```

**Why remote state:**
- Team collaboration (shared state)
- State locking (prevent concurrent modifications)
- Secure (encrypted at rest)
- Backup (don't lose infrastructure state)

---

## Azure (AKS) Provisioning

### Directory Structure

```
azure/
├── terraform/
│   ├── main.tf           # Main configuration
│   ├── variables.tf      # Input variables
│   ├── outputs.tf        # Output values
│   ├── terraform.tfvars  # Variable values (DO NOT commit secrets)
│   └── modules/
│       ├── aks/          # Reusable AKS module
│       ├── networking/   # VNet, subnets
│       └── storage/      # Storage accounts
```

### Example: AKS Cluster

**variables.tf:**
```hcl
variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "aks-cluster-01"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for worker nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28.3"
}
```

**main.tf:**
```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Remote state (production)
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "tfstate12345"
    container_name       = "tfstate"
    key                  = "aks-prod.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.cluster_name}"
  location = var.location

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.cluster_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet for AKS
resource "azurerm_subnet" "aks" {
  name                 = "subnet-aks"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = var.node_count
    vm_size             = var.node_vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 5
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.1.0.0/16"
    dns_service_ip    = "10.1.0.10"
  }

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

**outputs.tf:**
```hcl
output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "kubeconfig" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

output "cluster_fqdn" {
  value = azurerm_kubernetes_cluster.aks.fqdn
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}
```

**terraform.tfvars:**
```hcl
# DO NOT commit this file if it contains secrets
cluster_name       = "aks-prod-01"
location           = "eastus"
node_count         = 3
node_vm_size       = "Standard_D4s_v3"
kubernetes_version = "1.28.3"
```

### Usage

```bash
cd azure/terraform/

# Initialize
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply
# Enter 'yes' to confirm

# Get kubeconfig
terraform output -raw kubeconfig > ~/.kube/aks-config
export KUBECONFIG=~/.kube/aks-config

# Verify
kubectl get nodes

# Cleanup (dev only!)
terraform destroy
```

---

## AWS (EKS) Provisioning

### Example: EKS Cluster

**main.tf:**
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# VPC Module (reusable)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# EKS Module (reusable)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.16.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      desired_size = var.node_count
      min_size     = 2
      max_size     = 5

      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"  # Or "SPOT" for cheaper
    }
  }

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

# EBS CSI Driver (for PersistentVolumes)
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"
}
```

**variables.tf:**
```hcl
variable "cluster_name" {
  default = "eks-cluster-01"
}

variable "region" {
  default = "us-east-1"
}

variable "node_count" {
  default = 2
}

variable "node_instance_type" {
  default = "t3.medium"
}

variable "kubernetes_version" {
  default = "1.28"
}
```

### Usage

```bash
cd aws/terraform/

# Configure AWS credentials
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
# OR use aws configure

terraform init
terraform plan
terraform apply

# Get kubeconfig
aws eks update-kubeconfig --region us-east-1 --name eks-cluster-01

kubectl get nodes
```

---

## GCP (GKE) Provisioning

### Example: GKE Cluster

**main.tf:**
```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # Regional cluster (more reliable than zonal)
  node_locations = [
    "${var.region}-a",
    "${var.region}-b",
    "${var.region}-c"
  ]

  # Initial node pool (will be replaced by managed node pool)
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Workload Identity for secure GCP service access
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  autoscaling {
    min_node_count = 2
    max_node_count = 5
  }

  node_config {
    machine_type = var.node_machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
```

**variables.tf:**
```hcl
variable "project_id" {
  description = "GCP project ID"
}

variable "cluster_name" {
  default = "gke-cluster-01"
}

variable "region" {
  default = "us-central1"
}

variable "node_count" {
  default = 2
}

variable "node_machine_type" {
  default = "e2-standard-2"
}
```

### Usage

```bash
cd gcp/terraform/

# Authenticate
gcloud auth application-default login

# Set project
export TF_VAR_project_id="my-gcp-project"

terraform init
terraform plan
terraform apply

# Get kubeconfig
gcloud container clusters get-credentials gke-cluster-01 --region us-central1

kubectl get nodes
```

---

## Advanced Patterns

### Modules (DRY - Don't Repeat Yourself)

**modules/kubernetes-cluster/main.tf:**
```hcl
variable "provider" {
  type = string  # "azure", "aws", "gcp"
}

variable "cluster_name" {}
variable "node_count" {}

# Conditional resource creation based on provider
module "aks" {
  count  = var.provider == "azure" ? 1 : 0
  source = "./aks"
  # ...
}

module "eks" {
  count  = var.provider == "aws" ? 1 : 0
  source = "./eks"
  # ...
}

module "gke" {
  count  = var.provider == "gcp" ? 1 : 0
  source = "./gke"
  # ...
}
```

**Usage:**
```hcl
# Create AKS cluster
module "cluster" {
  source       = "./modules/kubernetes-cluster"
  provider     = "azure"
  cluster_name = "my-cluster"
  node_count   = 3
}
```

### Workspaces (Multiple Environments)

```bash
# Create dev workspace
terraform workspace new dev
terraform apply -var-file=dev.tfvars

# Create prod workspace
terraform workspace new prod
terraform apply -var-file=prod.tfvars

# List workspaces
terraform workspace list

# Switch workspace
terraform workspace select dev
```

### Data Sources (Query Existing Resources)

```hcl
# Use existing VNet instead of creating new one
data "azurerm_virtual_network" "existing" {
  name                = "existing-vnet"
  resource_group_name = "existing-rg"
}

resource "azurerm_subnet" "aks" {
  virtual_network_name = data.azurerm_virtual_network.existing.name
  # ...
}
```

---

## Hybrid Cloud Provisioning

### VPN Connection (On-Prem to Azure)

**main.tf:**
```hcl
# Azure side
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "azure-vpn-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  sku = "VpnGw1"

  ip_configuration {
    subnet_id            = azurerm_subnet.gateway.id
    public_ip_address_id = azurerm_public_ip.vpn.id
  }
}

# On-prem gateway representation
resource "azurerm_local_network_gateway" "onprem" {
  name                = "onprem-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  gateway_address = var.onprem_public_ip  # Your Proxmox public IP
  address_space   = ["192.168.1.0/24"]    # Your on-prem network
}

# VPN Connection
resource "azurerm_virtual_network_gateway_connection" "onprem" {
  name                = "onprem-to-azure"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id

  shared_key = var.vpn_shared_key  # Secure PSK
}
```

---

## Best Practices

### 1. State Management
```bash
# ALWAYS use remote state for teams
terraform {
  backend "azurerm" {
    # Store state in Azure Storage
  }
}
```

### 2. Variable Management
```hcl
# Never hardcode values
# BAD:
resource "azurerm_kubernetes_cluster" "aks" {
  name = "aks-cluster"  # Hardcoded
}

# GOOD:
resource "azurerm_kubernetes_cluster" "aks" {
  name = var.cluster_name  # Variable
}
```

### 3. Outputs
```hcl
# Always output important values
output "kubeconfig" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true  # Don't show in console
}
```

### 4. Tags
```hcl
# Tag everything for cost tracking
tags = {
  Environment = "Production"
  ManagedBy   = "Terraform"
  Owner       = "devops-team"
  CostCenter  = "engineering"
}
```

### 5. Locking
```hcl
# Prevent accidental deletion
lifecycle {
  prevent_destroy = true
}
```

### 6. Formatting
```bash
# Auto-format before commit
terraform fmt -recursive
```

### 7. Validation
```bash
# Validate syntax
terraform validate

# Check for security issues
tfsec .
```

---

## Terraform vs Alternatives

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **Terraform** | Multi-cloud IaC | Cross-cloud, team collaboration |
| **Bicep** | Azure-native IaC | Azure-only, Microsoft shops |
| **CloudFormation** | AWS-native IaC | AWS-only |
| **Pulumi** | IaC with programming languages | TypeScript/Python preference |
| **Ansible** | Configuration management | OS/app config, not provisioning |

**Use Terraform for:**
- Provisioning infrastructure (VMs, networks, K8s clusters)
- Multi-cloud deployments
- Team collaboration (state management)

**Use Ansible for:**
- Configuring provisioned resources (next: configuration.md)
- Installing software on VMs
- Kubernetes cluster add-ons

---

## Next Steps

After provisioning with Terraform:
1. Get kubeconfig: `terraform output -raw kubeconfig`
2. Configure cluster with Ansible (see `configuration.md`)
3. Deploy applications with kubectl (native) or GitOps (later)

---

*Last Updated: 2026-01-02*
