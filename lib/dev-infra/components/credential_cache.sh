#!/bin/bash
# Generic Credential Caching Framework for Devcontainers
#
# Usage:
#   source devcontainer/components/credential_cache.sh
#   setup_credential_cache "github" "cloudflare"
#
# Supported services: github, cloudflare, claude
#
# Each service follows three-tier authentication:
#   1. Check for cached credentials (bind-mounted directory)
#   2. Auto-convert environment variables (e.g., GITHUB_TOKEN)
#   3. Interactive fallback with user instructions

# Detect workspace root path dynamically
# Supports both /workspaces/<project> and custom paths
get_workspace_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Auth directory (always under workspace root)
AUTH_DIR="$(get_workspace_root)/temp/auth"

# Main entry point - setup credentials for requested services
# Usage: setup_credential_cache "github" "cloudflare"
setup_credential_cache() {
  local services=("$@")
  local failed_services=()

  # Create base auth directory
  mkdir -p "$AUTH_DIR"

  # Validate and setup each service
  for service in "${services[@]}"; do
    if declare -f "setup_${service}_auth" >/dev/null 2>&1; then
      if ! "setup_${service}_auth"; then
        failed_services+=("$service")
      fi
    else
      echo "⚠ Unknown service: $service (skipping)"
      failed_services+=("$service")
    fi
  done

  # Report failures but don't block startup
  if [ ${#failed_services[@]} -gt 0 ]; then
    echo "⚠ Some credentials not configured: ${failed_services[*]}"
    echo "  Container will start, but some features may require authentication"
  fi

  return 0  # Never block container startup
}

# GitHub CLI authentication
# Caches OAuth credentials in temp/auth/gh-config/
setup_github_auth() {
  export GH_CONFIG_DIR="$AUTH_DIR/gh-config"
  local HOSTS_FILE="$GH_CONFIG_DIR/hosts.yml"
  local SENTINEL_FILE="$AUTH_DIR/.gh-auth-checked"
  local SHARED_GH_DIR="/home/vscode/.shared-auth/gh"

  # Fix Docker volume ownership: Docker creates named volumes as root:root
  if [ -d "$SHARED_GH_DIR" ] && [ ! -w "$SHARED_GH_DIR" ]; then
    sudo chown -R "$(id -u):$(id -g)" "$SHARED_GH_DIR" 2>/dev/null || true
  fi

  # Sentinel: skip full check if already verified this container boot
  if [ -f "$SENTINEL_FILE" ]; then
    return 0
  fi

  # Ensure gh CLI is installed
  if ! command -v gh >/dev/null 2>&1; then
    echo "⚠ GitHub CLI (gh) not installed, skipping GitHub auth"
    return 1
  fi

  # Create directory with proper permissions
  mkdir -p "$GH_CONFIG_DIR"
  chmod 700 "$GH_CONFIG_DIR"

  # Shared auth volume: import credentials from shared volume
  if [ -d "$SHARED_GH_DIR" ] && [ -f "$SHARED_GH_DIR/hosts.yml" ] && [ ! -f "$HOSTS_FILE" ]; then
    cp "$SHARED_GH_DIR/hosts.yml" "$HOSTS_FILE"
    chmod 600 "$HOSTS_FILE"
    if [ -f "$SHARED_GH_DIR/config.yml" ] && [ ! -f "$GH_CONFIG_DIR/config.yml" ]; then
      cp "$SHARED_GH_DIR/config.yml" "$GH_CONFIG_DIR/config.yml"
    fi
  fi

  # Migrate: if credentials exist in default location but not in cache, copy them
  local DEFAULT_HOSTS="$HOME/.config/gh/hosts.yml"
  if [ ! -f "$HOSTS_FILE" ] && [ -f "$DEFAULT_HOSTS" ]; then
    cp "$DEFAULT_HOSTS" "$HOSTS_FILE"
    chmod 600 "$HOSTS_FILE"
    # Also copy config.yml if present
    if [ -f "$HOME/.config/gh/config.yml" ] && [ ! -f "$GH_CONFIG_DIR/config.yml" ]; then
      cp "$HOME/.config/gh/config.yml" "$GH_CONFIG_DIR/config.yml"
    fi
  fi

  # Tier 1: Check for cached credentials
  if [ -f "$HOSTS_FILE" ]; then
    echo "✓ GitHub CLI authenticated (cached)"
    # Shared auth volume: propagate to shared for other containers
    if [ -d "$SHARED_GH_DIR" ] && [ ! -f "$SHARED_GH_DIR/hosts.yml" ]; then
      cp "$HOSTS_FILE" "$SHARED_GH_DIR/hosts.yml"
      chmod 600 "$SHARED_GH_DIR/hosts.yml"
      [ -f "$GH_CONFIG_DIR/config.yml" ] && cp "$GH_CONFIG_DIR/config.yml" "$SHARED_GH_DIR/config.yml" 2>/dev/null || true
    fi
    touch "$SENTINEL_FILE"
    return 0
  fi

  # Tier 2: Auto-convert GITHUB_TOKEN if available
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "Converting GITHUB_TOKEN to cached OAuth credentials..."
    if echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null; then
      echo "✓ GitHub CLI authenticated automatically via GITHUB_TOKEN"
      # Shared auth volume: propagate to shared for other containers
      if [ -d "$SHARED_GH_DIR" ] && [ -f "$HOSTS_FILE" ] && [ ! -f "$SHARED_GH_DIR/hosts.yml" ]; then
        cp "$HOSTS_FILE" "$SHARED_GH_DIR/hosts.yml"
        chmod 600 "$SHARED_GH_DIR/hosts.yml"
        [ -f "$GH_CONFIG_DIR/config.yml" ] && cp "$GH_CONFIG_DIR/config.yml" "$SHARED_GH_DIR/config.yml" 2>/dev/null || true
      fi
      touch "$SENTINEL_FILE"
      return 0
    else
      echo "⚠ Failed to authenticate with GITHUB_TOKEN"
      return 1
    fi
  fi

  # Tier 2.5: Check if gh is authenticated via other mechanisms
  # (credential helpers, codespace token forwarding, keyring, etc.)
  if gh auth status >/dev/null 2>&1; then
    echo "✓ GitHub CLI authenticated"
    touch "$SENTINEL_FILE"
    return 0
  fi

  # Tier 3: Interactive fallback - only warn in interactive terminals
  if [ -t 1 ]; then
    echo ""
    echo "⚠ GitHub CLI not authenticated. Please run:"
    echo "  gh auth login"
    echo ""
    echo "Your credentials will be cached across container rebuilds."
    echo ""
  fi

  # Write sentinel even for unauthenticated state to avoid repeated warnings
  touch "$SENTINEL_FILE"

  return 0
}

# Claude shared auth volume sync
# Syncs ONLY .credentials.json between local and shared volume.
# NEVER syncs projects/, history.jsonl, or other per-project data.
setup_claude_shared_auth() {
  local SHARED_CLAUDE_DIR="/home/vscode/.shared-auth/claude"
  local CLAUDE_CREDS="$HOME/.claude/.credentials.json"

  # Skip if shared volume not mounted
  [ -d "$SHARED_CLAUDE_DIR" ] || return 0

  # Fix Docker volume ownership: Docker creates named volumes as root:root
  if [ ! -w "$SHARED_CLAUDE_DIR" ]; then
    sudo chown -R "$(id -u):$(id -g)" "$SHARED_CLAUDE_DIR" 2>/dev/null || true
  fi

  # Import: shared → local (pick up auth from another container)
  if [ -f "$SHARED_CLAUDE_DIR/.credentials.json" ] && [ ! -f "$CLAUDE_CREDS" ]; then
    mkdir -p "$HOME/.claude"
    cp "$SHARED_CLAUDE_DIR/.credentials.json" "$CLAUDE_CREDS"
    chmod 600 "$CLAUDE_CREDS"
  fi

  # Export: local → shared (first-auth propagation)
  if [ -f "$CLAUDE_CREDS" ] && [ ! -f "$SHARED_CLAUDE_DIR/.credentials.json" ]; then
    cp "$CLAUDE_CREDS" "$SHARED_CLAUDE_DIR/.credentials.json"
    chmod 600 "$SHARED_CLAUDE_DIR/.credentials.json"
  fi

  return 0
}

# Claude Code authentication
# Checks for cached credentials or ANTHROPIC_API_KEY
setup_claude_auth() {
  # Sync with shared auth volume before checking local credentials
  setup_claude_shared_auth

  local CLAUDE_CREDS="$HOME/.claude/.credentials.json"

  # Check cached credentials first (works regardless of CLI)
  if [ -f "$CLAUDE_CREDS" ]; then
    echo "✓ Claude Code authenticated"
    return 0
  fi

  # API key is sufficient without CLI installed
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "✓ Claude Code: ANTHROPIC_API_KEY detected"
    return 0
  fi

  if ! command -v claude >/dev/null 2>&1; then
    echo "⚠ Claude CLI not installed, skipping Claude auth"
    return 0
  fi

  echo ""
  echo "⚠ Claude Code not authenticated. Please run:"
  echo "  claude login"
  echo ""
  return 0
}

# Cloudflare authentication
# Supports both API token and Wrangler OAuth
setup_cloudflare_auth() {
  local CF_TOKEN_FILE="$AUTH_DIR/cloudflare_api_token"
  local WRANGLER_CONFIG_DIR="$AUTH_DIR/wrangler"

  # Create wrangler config directory
  mkdir -p "$WRANGLER_CONFIG_DIR"
  chmod 700 "$WRANGLER_CONFIG_DIR"

  # Tier 1: Check for cached credentials (API token or Wrangler config)
  if [ -f "$CF_TOKEN_FILE" ]; then
    echo "✓ Cloudflare API token found in cache"
    export CLOUDFLARE_API_TOKEN="$(cat "$CF_TOKEN_FILE")"
    return 0
  fi

  # Check for cached Wrangler config
  if [ -f "$WRANGLER_CONFIG_DIR/default.toml" ]; then
    echo "✓ Wrangler config found in cache"
    mkdir -p ~/.wrangler/config
    ln -sf "$WRANGLER_CONFIG_DIR/default.toml" ~/.wrangler/config/default.toml
    return 0
  fi

  # Tier 2: Auto-cache CLOUDFLARE_API_TOKEN if set
  if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    echo "${CLOUDFLARE_API_TOKEN}" > "$CF_TOKEN_FILE"
    chmod 600 "$CF_TOKEN_FILE"
    echo "✓ Cloudflare API token cached from environment"
    return 0
  fi

  # Tier 3: Interactive fallback
  echo "⚠ Cloudflare credentials not found. Options:"
  echo "  1. Set CLOUDFLARE_API_TOKEN environment variable"
  echo "  2. Run: wrangler login"
  echo ""

  return 0
}
