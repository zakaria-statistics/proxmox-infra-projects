#!/bin/bash
# Kubernetes Complete Debugging Toolset Installer
# Run this on your control plane or workstation

set -e

echo "=== Installing Kubernetes Debugging & Management Tools ==="

# 1. k9s - Terminal UI for Kubernetes
echo "📦 Installing k9s..."
curl -sS https://webinstall.dev/k9s | bash
export PATH="$HOME/.local/bin:$PATH"

# 2. stern - Multi-pod log tailing
echo "📦 Installing stern..."
cd /tmp
wget -q https://github.com/stern/stern/releases/download/v1.28.0/stern_1.28.0_linux_amd64.tar.gz
tar -xzf stern_1.28.0_linux_amd64.tar.gz
sudo mv stern /usr/local/bin/
rm stern_1.28.0_linux_amd64.tar.gz

# 3. kubectx & kubens - Context/Namespace switching
echo "📦 Installing kubectx & kubens..."
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx 2>/dev/null || echo "Already exists"
sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens

# 4. krew - kubectl plugin manager
echo "📦 Installing krew..."
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# Add krew to PATH permanently
echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bashrc
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# 5. kubectl plugins via krew
echo "📦 Installing kubectl plugins..."
kubectl krew install tree        # Resource hierarchy
kubectl krew install neat        # Clean YAML output
kubectl krew install ctx         # Context switcher
kubectl krew install ns          # Namespace switcher
kubectl krew install tail        # Pod log tailing
kubectl krew install resource-capacity  # Resource usage

# 6. dive - Container image layer inspector
echo "📦 Installing dive..."
cd /tmp
wget -q https://github.com/wagoodman/dive/releases/download/v0.11.0/dive_0.11.0_linux_amd64.tar.gz
tar -xzf dive_0.11.0_linux_amd64.tar.gz
sudo mv dive /usr/local/bin/
rm dive_0.11.0_linux_amd64.tar.gz

# 7. jq - JSON processor (if not already installed)
echo "📦 Installing jq..."
sudo apt-get update -qq && sudo apt-get install -y jq

# 8. yq - YAML processor
echo "📦 Installing yq..."
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

echo ""
echo "✅ All tools installed successfully!"
echo ""
echo "=== Verify Installation ==="
echo "k9s version:        $(k9s version 2>/dev/null | head -1 || echo 'Not found')"
echo "stern version:      $(stern --version 2>/dev/null || echo 'Not found')"
echo "kubectx:            $(kubectx --version 2>/dev/null || echo 'Not found')"
echo "kubectl krew:       $(kubectl krew version 2>/dev/null || echo 'Not found')"
echo "dive version:       $(dive --version 2>/dev/null || echo 'Not found')"
echo "jq version:         $(jq --version 2>/dev/null || echo 'Not found')"
echo "yq version:         $(yq --version 2>/dev/null || echo 'Not found')"
echo ""
echo "=== Quick Start ==="
echo "Launch k9s:         k9s"
echo "Tail logs:          stern <pod-pattern>"
echo "Switch namespace:   kubens <namespace>"
echo "View pod tree:      kubectl tree deployment <name>"
echo "Clean YAML:         kubectl get pod <name> -o yaml | kubectl neat"
echo ""
echo "⚠️  IMPORTANT: Restart your shell or run: source ~/.bashrc"
