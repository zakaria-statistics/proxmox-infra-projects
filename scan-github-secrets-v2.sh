#!/bin/bash
# GitGuardian Secret Scanning Script v2
# Works with GitGuardian GitHub App installations

set -e

# Add ggshield to PATH
export PATH="/root/.local/bin:$PATH"

# Check if API token is set
if [ -z "$GITGUARDIAN_API_KEY" ]; then
    echo "Error: GITGUARDIAN_API_KEY environment variable not set"
    echo ""
    echo "Get your API token from: https://dashboard.gitguardian.com/api/personal-access-tokens"
    echo "Then run: export GITGUARDIAN_API_KEY='your-token-here'"
    exit 1
fi

echo "=== GitGuardian Secret Scan ==="
echo ""

# Check API status
echo "🔍 Checking API connection..."
ggshield api-status
echo ""

# Check quota
echo "📊 Checking quota..."
ggshield quota
echo ""

# Note about GitHub App incidents
echo "⚠️  GitHub App Incidents:"
echo "If you installed GitGuardian as a GitHub App, incidents are shown in:"
echo "👉 https://dashboard.gitguardian.com/incidents"
echo ""
echo "The API endpoint for incidents may require an Enterprise plan."
echo ""

# Offer to scan local repos
echo "📂 To scan a local repository:"
echo "   cd /path/to/repo"
echo "   ggshield secret scan repo ."
echo ""

# Show where to view findings
echo "=== View All Findings ==="
echo "🌐 Dashboard: https://dashboard.gitguardian.com"
echo "📋 Incidents: https://dashboard.gitguardian.com/incidents"
echo "📦 Sources: https://dashboard.gitguardian.com/sources"
echo ""
