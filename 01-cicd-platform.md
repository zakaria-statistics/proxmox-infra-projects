# CI/CD Platform (Dev/Build Tier)

## Overview

Lightweight continuous integration and delivery platform for building, testing, and deploying containerized applications.

## Infrastructure Type

**LXC Container** - No kernel isolation needed, optimized for resource efficiency

## Components

- **GitLab** (or Gitea + Drone/Woodpecker for lighter alternative)
- Container registry (built-in with GitLab or Harbor)
- Build agents/runners
- Artifact storage

## Resource Allocation

- **RAM:** 3-4GB
- **vCPU:** 4 cores
- **Storage:** 50-100GB (depending on build cache and artifacts)

## Key Features

### Source Control
- Git repository hosting
- Branch management
- Merge/Pull request workflows
- Code review capabilities

### Build Pipeline
- Automated builds on commit/PR
- Multi-stage build support
- Docker image building
- Build artifact caching

### Container Registry
- Private Docker registry
- Image tagging and versioning
- Vulnerability scanning (optional)
- Image cleanup policies

### Testing
- Unit test execution
- Integration test support
- Code quality checks (linting, static analysis)
- Test result reporting

## Integration Points

```
Developer → GitLab → Build Pipeline → Container Registry → K8s Platform
```

## Implementation Steps

### 1. LXC Container Setup
```bash
# Create LXC container on Proxmox
pct create 100 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname cicd-platform \
  --cores 4 \
  --memory 4096 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-lvm \
  --rootfs local-lvm:50
```

### 2. GitLab Installation (Option A)

```bash
# Inside LXC container
apt update && apt upgrade -y
apt install -y curl openssh-server ca-certificates tzdata perl

# Add GitLab repository
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash

# Install GitLab
apt install gitlab-ce

# Configure and start
gitlab-ctl reconfigure
```

### 3. Gitea + Drone (Option B - Lighter)

```bash
# Install Docker in LXC
apt install -y docker.io docker-compose

# Create docker-compose.yml for Gitea + Drone
cat > docker-compose.yml <<EOF
version: '3'
services:
  gitea:
    image: gitea/gitea:latest
    ports:
      - "3000:3000"
      - "2222:22"
    volumes:
      - ./gitea:/data

  drone-server:
    image: drone/drone:latest
    ports:
      - "8080:80"
    volumes:
      - ./drone:/data
    environment:
      - DRONE_GITEA_SERVER=http://gitea:3000

  drone-runner:
    image: drone/drone-runner-docker:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF

docker-compose up -d
```

### 4. Configure Container Registry

**GitLab (built-in):**
```bash
# Enable container registry in gitlab.rb
registry_external_url 'https://registry.yourdomain.com'
gitlab_rails['registry_enabled'] = true

gitlab-ctl reconfigure
```

**Harbor (standalone):**
```bash
# Download and install Harbor
wget https://github.com/goharbor/harbor/releases/download/v2.9.0/harbor-offline-installer-v2.9.0.tgz
tar xzvf harbor-offline-installer-v2.9.0.tgz
cd harbor
./install.sh
```

### 5. Setup CI/CD Pipeline

Example `.gitlab-ci.yml`:
```yaml
stages:
  - build
  - test
  - push

build:
  stage: build
  script:
    - docker build -t myapp:${CI_COMMIT_SHA} .

test:
  stage: test
  script:
    - docker run myapp:${CI_COMMIT_SHA} npm test

push:
  stage: push
  script:
    - docker tag myapp:${CI_COMMIT_SHA} registry.local/myapp:latest
    - docker push registry.local/myapp:latest
  only:
    - main
```

## Network Configuration

- **VLAN:** Main development network
- **Firewall Rules:**
  - Allow HTTP/HTTPS (80, 443) for web UI
  - Allow SSH (22) for git operations
  - Allow custom registry port (5000) for image push/pull
  - Allow communication to K8s cluster

## Security Considerations

- Enable HTTPS with Let's Encrypt or self-signed certificates
- Configure LDAP/AD integration for user authentication
- Set up SSH key-based git access
- Implement webhook secrets for pipeline triggers
- Regular security updates and patches
- Container image scanning

## Backup Strategy

```bash
# GitLab backup
gitlab-backup create

# Store in external location
cp /var/opt/gitlab/backups/* /mnt/backup/
```

## Monitoring

- GitLab/Gitea built-in metrics
- Pipeline success/failure rates
- Build duration tracking
- Resource utilization (CPU, RAM, disk)

## Cost-Benefit Analysis

**Why LXC?**
- Lower memory footprint vs VM
- Faster startup times
- Stateless build processes don't need kernel isolation
- Easy snapshots and backups

**GitLab vs Gitea+Drone:**
- **GitLab**: All-in-one, feature-rich, higher resource usage
- **Gitea+Drone**: Lightweight, modular, lower resource usage

## Next Steps

1. Deploy LXC container
2. Choose and install CI/CD platform
3. Configure container registry
4. Create sample pipeline
5. Integrate with K8s platform for deployments

---

**Related Projects:**
- [K8s Platform](./02-k8s-platform.md) - Deployment target
- [DB Cluster](./03-db-cluster.md) - Database services
