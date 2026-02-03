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

    # Gastown multi-agent orchestration setup
    setup_gastown() {
        if ! command -v gt >/dev/null 2>&1; then
            return 0
        fi

        export GASTOWN_HOME="${GASTOWN_HOME:-$HOME/gt}"

        # Initialize workspace if not already present
        if [ ! -d "$GASTOWN_HOME/.gastown" ]; then
            gt install "$GASTOWN_HOME" --name dev-town 2>/dev/null || true
        fi

        # Merge gastown hooks into Claude Code settings.json
        local CLAUDE_SETTINGS="$HOME/.claude/settings.json"
        if [ ! -f "$CLAUDE_SETTINGS" ] || ! python3 -c "
import json, sys
with open('$CLAUDE_SETTINGS') as f:
    data = json.load(f)
sys.exit(0 if 'hooks' in data and 'Stop' in data['hooks'] else 1)
" 2>/dev/null; then
            mkdir -p "$HOME/.claude"
            python3 -c "
import json, os

settings_path = '$CLAUDE_SETTINGS'

# Load existing settings or start fresh
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

gastown_hooks = {
    'SessionStart': [{'command': 'gt prime --hook 2>/dev/null || true'}],
    'PreCompact': [{'command': 'gt prime --hook 2>/dev/null || true'}],
    'UserPromptSubmit': [{'command': 'gt mail check --inject 2>/dev/null || true'}],
    'PreToolUse': [
        {'matcher': 'Bash(gh pr create*)', 'command': 'gt tap guard pr-workflow 2>/dev/null || true'},
        {'matcher': 'Bash(git checkout -b*)', 'command': 'gt tap guard pr-workflow 2>/dev/null || true'},
        {'matcher': 'Bash(git switch -c*)', 'command': 'gt tap guard pr-workflow 2>/dev/null || true'}
    ],
    'Stop': [{'command': 'gt costs record 2>/dev/null || true'}]
}

# Merge hooks: append gastown hooks to any existing hooks per event
existing_hooks = settings.get('hooks', {})
for event, hooks in gastown_hooks.items():
    if event not in existing_hooks:
        existing_hooks[event] = []
    existing_cmds = {h.get('command') for h in existing_hooks[event]}
    for hook in hooks:
        if hook['command'] not in existing_cmds:
            existing_hooks[event].append(hook)

settings['hooks'] = existing_hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
" 2>/dev/null || true
        fi
    }
    setup_gastown

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
alias gt-status='gt status'
alias gt-doctor='gt doctor'

# Extensible - projects can add their own aliases
# Place project-specific aliases in /workspace/.devcontainer/aliases.sh
if [ -f "/workspace/.devcontainer/aliases.sh" ]; then
    source "/workspace/.devcontainer/aliases.sh" 2>/dev/null || true
fi
