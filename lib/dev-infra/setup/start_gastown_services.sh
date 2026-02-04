#!/usr/bin/env bash
# Start gastown long-lived services and run credential cache setup.
# Called from devcontainer postStartCommand (via image LABEL).
# Runs on every container start, including after initial creation.
# Idempotent: gt up only starts services that aren't already running.
set -euo pipefail

# Run credential cache setup for non-interactive shells.
# Interactive shells get this via /etc/profile.d/ai-dev-utils.sh, but
# postStartCommand runs non-interactively.
# Projects can override services via CREDENTIAL_SERVICES env var.
# Default: "github claude" (same as ai-dev-utils.sh interactive setup)
if [ -f "/opt/dev-infra/credential_cache.sh" ]; then
  source "/opt/dev-infra/credential_cache.sh"
  # shellcheck disable=SC2086
  setup_credential_cache ${CREDENTIAL_SERVICES:-github claude} || true
fi

if ! command -v gt >/dev/null 2>&1; then
  exit 0
fi

GASTOWN_HOME="${GASTOWN_HOME:-$HOME/gt}"

# Only start services if gastown HQ is initialized
if [ ! -f "$GASTOWN_HOME/mayor/town.json" ]; then
  exit 0
fi

cd "$GASTOWN_HOME" && gt up -q 2>/dev/null || true
