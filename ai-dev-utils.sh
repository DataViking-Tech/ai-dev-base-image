#!/bin/bash
# AI Dev Utilities - Auto-sourced on shell startup
# Provides dev-infra components and extensible aliases

# Source dev-infra components if available
if [ -d /opt/dev-infra ]; then
    # Credential caching framework
    if [ -f /opt/dev-infra/credential_cache.sh ]; then
        source /opt/dev-infra/credential_cache.sh
    fi

    # Directory creation component
    if [ -f /opt/dev-infra/directories.sh ]; then
        source /opt/dev-infra/directories.sh
    fi

    # Python venv component
    if [ -f /opt/dev-infra/python_venv.sh ]; then
        source /opt/dev-infra/python_venv.sh
    fi

    # Git hooks component
    if [ -f /opt/dev-infra/git_hooks.sh ]; then
        source /opt/dev-infra/git_hooks.sh
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
if [ -f /workspace/.devcontainer/aliases.sh ]; then
    source /workspace/.devcontainer/aliases.sh
fi
