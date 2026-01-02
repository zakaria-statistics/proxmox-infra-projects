# GitHub Secret Scanning with GitGuardian

## Quick Start

Since you already have GitGuardian installed on your GitHub account, we can fetch all findings via their API.

### Step 1: Get Your GitGuardian API Token

1. Visit: https://dashboard.gitguardian.com/api/personal-access-tokens
2. Click "Create token"
3. Give it a name (e.g., "CLI Access")
4. Copy the token

### Step 2: Run the Scan

```bash
# Set your API token (replace with your actual token)
export GITGUARDIAN_API_KEY='your-token-here'

# Run the scan script
./scan-github-secrets.sh
```

### Alternative: Manual Commands

```bash
# Add ggshield to PATH
export PATH="/root/.local/bin:$PATH"

# Authenticate with GitGuardian
ggshield auth login --api-key $GITGUARDIAN_API_KEY

# Fetch all incidents from GitGuardian dashboard
# (These are secrets already found by the GitHub App)
curl -H "Authorization: Token $GITGUARDIAN_API_KEY" \
  "https://api.gitguardian.com/v1/incidents?per_page=100" | jq

# Or list repositories being monitored
curl -H "Authorization: Token $GITGUARDIAN_API_KEY" \
  "https://api.gitguardian.com/v1/sources" | jq

# Scan a specific local repo
cd /path/to/repo
ggshield secret scan repo .
```

### Step 3: Review Findings

The script will output:
- Repository where secret was found
- Type of secret detected (API key, token, etc.)
- Status (triggered, resolved, ignored)

## Understanding GitGuardian Integration

```
GitHub Repository (push/commit)
  ↓ monitored by
GitGuardian GitHub App
  ↓ scans for
Secrets/API keys/credentials
  ↓ stores findings in
GitGuardian Dashboard
  ↓ accessible via
GitGuardian API
  ↓ queried by
ggshield CLI or direct API calls
```

## API Endpoints Available

- **List incidents:** `GET /v1/incidents`
- **Get incident details:** `GET /v1/incidents/{incident_id}`
- **List sources (repos):** `GET /v1/sources`
- **Get source health:** `GET /v1/sources/{source_id}/health`

Full API docs: https://api.gitguardian.com/docs

## Next Steps: Build security-mcp Server

Once you verify this works, we can build a proper MCP server that:

1. **Exposes GitGuardian findings as MCP resources**
   - `security://secrets/summary` - Overview of all findings
   - `security://secrets/repo/{repo}` - Per-repo findings
   - `security://secrets/critical` - High-severity only

2. **Integrates other security tools**
   - Trivy for container scanning
   - Gitleaks for local repo scanning
   - SAST/DAST results aggregation

3. **Provides remediation guidance**
   - Auto-suggest fixes for common secrets
   - Generate .gitignore rules
   - Create secret rotation plans

This aligns with your infrastructure roadmap (Phase 5/6).

## Troubleshooting

**Authentication failed:**
- Check token is valid: https://dashboard.gitguardian.com/api/personal-access-tokens
- Ensure no extra spaces in token

**No incidents found:**
- GitGuardian GitHub App scans on push events
- Check dashboard: https://dashboard.gitguardian.com
- Verify repos are connected in GitGuardian settings

**Rate limiting:**
- API has rate limits (check response headers)
- Upgrade to paid plan for higher limits if needed