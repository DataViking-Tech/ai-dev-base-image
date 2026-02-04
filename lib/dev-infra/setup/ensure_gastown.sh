#!/usr/bin/env bash
# Ensure gastown is initialized in the current container.
# Called from devcontainer postCreateCommand (via image LABEL).
# Idempotent: skips workspace init if town.json already exists,
# skips hook merge if hooks are already present.
set -euo pipefail

if ! command -v gt >/dev/null 2>&1; then
  exit 0
fi

GASTOWN_HOME="${GASTOWN_HOME:-$HOME/gt}"

# Fix ownership if the directory was created by a Docker volume mount (root-owned)
if [ -d "$GASTOWN_HOME" ] && [ "$(stat -c '%u' "$GASTOWN_HOME" 2>/dev/null)" != "$(id -u)" ]; then
  sudo chown -R "$(id -u):$(id -g)" "$GASTOWN_HOME" 2>/dev/null || true
fi

# Initialize workspace if not already present
if [ ! -f "$GASTOWN_HOME/mayor/town.json" ]; then
  gt install "$GASTOWN_HOME" --name dev-town 2>/dev/null || true
fi

# Merge gastown hooks into Claude Code settings.json (idempotent)
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Check if hooks are already merged (Stop hook as sentinel)
if [ -f "$CLAUDE_SETTINGS" ] && python3 -c "
import json, sys
with open('$CLAUDE_SETTINGS') as f:
    data = json.load(f)
sys.exit(0 if 'hooks' in data and 'Stop' in data['hooks'] else 1)
" 2>/dev/null; then
  exit 0
fi

mkdir -p "$HOME/.claude"
python3 -c "
import json, os

settings_path = '$CLAUDE_SETTINGS'

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
