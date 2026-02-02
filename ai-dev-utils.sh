#!/bin/bash
# AI Dev Utilities - Auto-sourced on shell startup
# Provides dev-infra components and extensible aliases

# Double-source guard: skip if already loaded in this shell session
if [ -n "${_AI_DEV_UTILS_LOADED:-}" ]; then
    return 0 2>/dev/null || true
fi
_AI_DEV_UTILS_LOADED=1

# Source dev-infra components if available
# Note: dev-infra scripts use 'set -euo pipefail' which would pollute the
# interactive shell. We save/restore shell options to prevent this.
if [ -d "/opt/dev-infra" ]; then
    # Save current shell options
    _ai_dev_old_opts=$(set +o)
    _ai_dev_old_shopt=$(shopt -p 2>/dev/null || true)

    # Credential caching framework
    if [ -f "/opt/dev-infra/credential_cache.sh" ]; then
        source "/opt/dev-infra/credential_cache.sh" 2>/dev/null || true

        # Claude Code credential check
        # Credentials persist via Docker volume mount at ~/.claude (see Dockerfile)
        setup_claude_auth() {
          local CLAUDE_CREDS="$HOME/.claude/.credentials.json"

          if ! command -v claude >/dev/null 2>&1; then
            echo "⚠ Claude CLI not installed, skipping Claude auth"
            return 1
          fi

          if [ -f "$CLAUDE_CREDS" ]; then
            echo "✓ Claude Code authenticated"
            return 0
          fi

          if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
            echo "✓ Claude Code: ANTHROPIC_API_KEY detected"
            return 0
          fi

          echo ""
          echo "⚠ Claude Code not authenticated. Please run:"
          echo "  claude login"
          echo ""
          return 0
        }

        # Run the 3-tier auth setup for GitHub and Claude
        setup_credential_cache "github" "claude" || true
    fi

    # Directory creation component
    if [ -f "/opt/dev-infra/directories.sh" ]; then
        source "/opt/dev-infra/directories.sh" 2>/dev/null || true
    fi

    # Python venv component
    if [ -f "/opt/dev-infra/python_venv.sh" ]; then
        source "/opt/dev-infra/python_venv.sh" 2>/dev/null || true
    fi

    # Git hooks component
    if [ -f "/opt/dev-infra/git_hooks.sh" ]; then
        source "/opt/dev-infra/git_hooks.sh" 2>/dev/null || true
    fi

    # Restore original shell options (prevents 'set -u' from persisting)
    eval "$_ai_dev_old_opts" 2>/dev/null || true
    eval "$_ai_dev_old_shopt" 2>/dev/null || true
    unset _ai_dev_old_opts _ai_dev_old_shopt
fi

# Standard bash aliases
alias bd-ready='bd ready'
alias bd-sync='bd sync'
alias bd-list='bd list'
alias py='python3'
alias pip='pip3'

# Extensible - projects can add their own aliases
# Place project-specific aliases in /workspace/.devcontainer/aliases.sh
if [ -f "/workspace/.devcontainer/aliases.sh" ]; then
    source "/workspace/.devcontainer/aliases.sh" 2>/dev/null || true
fi
