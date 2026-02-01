# AI Dev Base Image — Installed Utilities

> Auto-generated reference for tools baked into `ai-dev-base`.
> Downstream images append their own sections to this file.

---

## System Packages

| Package           | Description                              |
|-------------------|------------------------------------------|
| `git`             | Distributed version control              |
| `curl`            | URL data transfer                        |
| `wget`            | Network file retrieval                   |
| `build-essential` | GCC, make, and core build toolchain      |
| `nodejs`          | JavaScript runtime (system package)      |

## Python & Package Managers

| Tool       | Description                                          |
|------------|------------------------------------------------------|
| `uv`       | Fast Python package manager (system-wide)            |
| `uvx`      | Run Python tools in ephemeral environments           |
| `python3`  | Python 3.11 installed via uv, symlinked to `/usr/local/bin` |
| `bun`      | JavaScript/TypeScript runtime and package manager    |

## AI / Dev Tools

| Tool       | Description                                          |
|------------|------------------------------------------------------|
| `claude`   | Claude CLI — Anthropic's AI assistant                |
| `codex`    | OpenAI Codex CLI (installed globally via Bun)        |
| `gh`       | GitHub CLI — repo, PR, and issue management          |
| `bd`       | Beads — issue tracking for AI workflows              |

## Embedded Components

### ai-coding-utils (`/opt/ai-coding-utils`)

Bundled Python packages for workflow integration:

- **slack** — Slack notification helpers
- **beads** — Beads workflow utilities

Dependencies: `requests`, `pyyaml` (installed via uv).
Added to `PYTHONPATH` automatically.

### dev-infra (`/opt/dev-infra`)

Shell components sourced automatically in all interactive shells via `/etc/profile.d/ai-dev-utils.sh`:

| Script                | Purpose                          |
|-----------------------|----------------------------------|
| `credential_cache.sh` | Credential caching framework    |
| `directories.sh`      | Workspace directory creation    |
| `python_venv.sh`      | Python virtualenv management    |
| `git_hooks.sh`        | Git hooks configuration         |

Also includes a `secrets/` module for secrets management.

## Shell Aliases

Defined in `/etc/profile.d/ai-dev-utils.sh` and available in every shell:

| Alias      | Expands to   |
|------------|-------------|
| `bd-ready` | `bd ready`  |
| `bd-sync`  | `bd sync`   |
| `bd-list`  | `bd list`   |
| `py`       | `python3`   |
| `pip`      | `pip3`      |

Projects can add custom aliases by placing a file at
`/workspace/.devcontainer/aliases.sh` — it is sourced automatically.
