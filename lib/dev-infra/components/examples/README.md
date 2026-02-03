# Credential Cache Integration Examples

Reference configurations showing how to integrate the credential cache component.

## Files

- `devcontainer.json` - Example devcontainer configuration with required mounts
- `postStartCommand.sh` - Example startup script using credential cache

## Usage

1. Add dev-infra as a git submodule (if not already present):
   ```bash
   git submodule add https://github.com/DataViking-Tech/dev-infra.git tooling/dev-infra
   ```

2. Copy example files to your project's `.devcontainer/` directory:
   ```bash
   cp devcontainer/components/examples/* .devcontainer/
   ```

3. Adapt the files for your project (change name, add features, etc.)

4. Add `temp/` to your `.gitignore` (REQUIRED)

See [../README.md](../README.md) for complete documentation.
