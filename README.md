# AI Dev Base Image

Foundation Docker image for AI coding workflows with embedded utilities.

## What's Included

- **Claude CLI** - AI assistant command-line tool
- **Beads (bd)** - Issue tracking for AI workflows
- **dev-infra components** - SecretsManager, credential caching, directory setup
- **ai-coding-utils** - Slack notifications, workflow integration
- **Bash utilities** - Auto-sourced aliases and functions

## Usage

```json
{
  "image": "ghcr.io/dataviking-tech/ai-dev-base:v2.0"
}
```

## Versions

- `v2` - Latest v2.x.x (semi-automatic updates)
- `v2.0` - Latest v2.0.x (patch updates)
- `v2.0.0` - Immutable release
- `edge` - Latest from main (nightly)

## Component Versions

This image includes:
- ai-coding-utils: v1.0.5
- dev-infra: v1.0.4
- Claude CLI: latest
- Beads: 0.49.2

## Building Locally

```bash
docker build -t ai-dev-base:local .
```

## Extending

```dockerfile
FROM ghcr.io/dataviking-tech/ai-dev-base:v2.0

# Add your tools
RUN apt-get update && apt-get install -y mytool
```

## License

See parent organization license.
