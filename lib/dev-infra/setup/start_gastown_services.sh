#!/usr/bin/env bash
# Start gastown long-lived services (daemon, deacon, witnesses, refineries).
# Called from devcontainer postStartCommand (via image LABEL).
# Runs on every container start, including after initial creation.
# Idempotent: gt up only starts services that aren't already running.
set -euo pipefail

if ! command -v gt >/dev/null 2>&1; then
  exit 0
fi

GASTOWN_HOME="${GASTOWN_HOME:-$HOME/gt}"

# Only start services if gastown HQ is initialized
if [ ! -f "$GASTOWN_HOME/mayor/town.json" ]; then
  exit 0
fi

cd "$GASTOWN_HOME" && gt up -q 2>/dev/null || true
