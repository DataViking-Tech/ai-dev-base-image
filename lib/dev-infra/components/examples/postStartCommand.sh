#!/bin/bash
# Example devcontainer startup script with credential caching
#
# Prerequisites:
#   1. Add dev-infra as git submodule:
#      git submodule add https://github.com/DataViking-Tech/dev-infra.git tooling/dev-infra
#   2. Add 'temp/' to .gitignore (REQUIRED for security)
#   3. Make this file executable: chmod +x .devcontainer/postStartCommand.sh
#
# Documentation: tooling/dev-infra/devcontainer/components/README.md

# Source the credential cache component
source tooling/dev-infra/devcontainer/components/credential_cache.sh

# Setup credentials for services this project needs
setup_credential_cache "github" "cloudflare"

# Rest of project-specific setup
echo "✓ Container setup complete"
