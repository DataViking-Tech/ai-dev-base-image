#!/bin/bash
# AI Dev Utilities - Auto-sourced on shell startup
# Provides dev-infra components and extensible aliases

# Double-source guard: skip if already loaded in this shell session
if [ -n "${_AI_DEV_UTILS_LOADED:-}" ]; then
    return 0 2>/dev/null || true
fi
_AI_DEV_UTILS_LOADED=1

# Source dev-infra components if available
if [ -d "/opt/dev-infra" ]; then
    # Credential caching framework
    if [ -f "/opt/dev-infra/credential_cache.sh" ]; then
        source "/opt/dev-infra/credential_cache.sh" 2>/dev/null || true
        # Run the 3-tier auth setup for GitHub
        setup_credential_cache "github" || true
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
