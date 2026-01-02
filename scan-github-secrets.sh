#!/bin/bash
# GitGuardian Secret Scanning Script
# Scans all repositories in GitHub account for secrets/sensitive data

set -e

# Check if API token is set
if [ -z "$GITGUARDIAN_API_KEY" ]; then
    echo "Error: GITGUARDIAN_API_KEY environment variable not set"
    echo ""
    echo "Get your API token from: https://dashboard.gitguardian.com/api/personal-access-tokens"
    echo "Then run: export GITGUARDIAN_API_KEY='your-token-here'"
    exit 1
fi

# Add ggshield to PATH
export PATH="/root/.local/bin:$PATH"

echo "=== GitGuardian Secret Scan Summary ==="
echo "Fetching incidents from GitGuardian..."
echo ""

# Get list of incidents from GitGuardian API
# This fetches all secrets found across all monitored repositories
ggshield secret scan repo-list || {
    echo "Note: If you haven't scanned repos yet, use 'ggshield scan' on individual repos"
}

echo ""
echo "=== Fetching detailed incidents via API ==="
echo ""

# Use GitGuardian API to get incident summary
# This requires curl and jq for JSON parsing
if command -v jq >/dev/null 2>&1; then
    curl -s -H "Authorization: Token $GITGUARDIAN_API_KEY" \
         "https://api.gitguardian.com/v1/incidents?per_page=100" | \
    jq -r '.incidents[] | "Repo: \(.repository_url) | Secret: \(.detector.display_name) | Status: \(.status)"'
else
    echo "Install 'jq' for better formatting: apt-get install jq"
    curl -s -H "Authorization: Token $GITGUARDIAN_API_KEY" \
         "https://api.gitguardian.com/v1/incidents?per_page=100"
fi

echo ""
echo "=== Summary Complete ==="
echo "For detailed analysis, visit: https://dashboard.gitguardian.com"