#!/usr/bin/env bash
# Devcontainer postStartCommand: credential setup + gastown services.
# Called from devcontainer postStartCommand (via image LABEL).
# Runs on every container start, including after initial creation.
# Idempotent: credential cache checks are non-blocking, gt up only starts
# services that aren't already running.
set -euo pipefail

# --- Credential cache setup ---
# Run before gastown services so credentials are available to agents.
# Interactive shells get this via /etc/profile.d/ai-dev-utils.sh;
# postStartCommand runs non-interactively, so we run it here too.
# Services default to "github cloudflare claude"; projects can override via env var.
#   e.g. in devcontainer.json containerEnv:
#     "CREDENTIAL_CACHE_SERVICES": "github claude"
if [ -f "/opt/dev-infra/credential_cache.sh" ]; then
  source "/opt/dev-infra/credential_cache.sh"
  IFS=' ' read -ra _services <<< "${CREDENTIAL_CACHE_SERVICES:-github cloudflare claude}"
  setup_credential_cache "${_services[@]}" || true
  unset _services
  # Verify credentials propagated correctly; re-import from shared if needed
  verify_credential_propagation || true
fi

# --- Gastown services ---
# Skip gastown services if disabled via env var (default: enabled)
if [ "${GASTOWN_ENABLED:-true}" = "false" ] || ! command -v gt >/dev/null 2>&1; then
  exit 0
fi

GASTOWN_HOME="${GASTOWN_HOME:-$HOME/gt}"

# Only start services if gastown HQ is initialized
if [ ! -f "$GASTOWN_HOME/mayor/town.json" ]; then
  exit 0
fi

cd "$GASTOWN_HOME" && gt up -q 2>/dev/null || true

# --- Daemon health watchdog ---
# Runs in background to detect and restart crashed daemon.
# Idempotent: script checks its own PID file before starting.
WATCHDOG_SCRIPT="/opt/dev-infra/setup/daemon_watchdog.sh"
if [ -f "$WATCHDOG_SCRIPT" ]; then
  nohup "$WATCHDOG_SCRIPT" </dev/null >/dev/null 2>&1 &
  disown
fi
