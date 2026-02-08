FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Build arguments for external binary versions
ARG BEADS_VERSION=0.49.3
ARG GASTOWN_VERSION=0.5.0

# Install system dependencies (excluding nodejs - installed separately below)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    build-essential \
    tmux \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 LTS via NodeSource (wrangler requires Node 20+)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN (type -p wget >/dev/null || (apt-get update && apt-get install -y wget)) && \
    mkdir -p -m 755 /etc/apt/keyrings && \
    out=$(mktemp) && wget -qO "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg && \
    cat "$out" | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install uv (Python package manager) to system-wide location
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh && \
    chmod +x /usr/local/bin/uv /usr/local/bin/uvx

# Install Python 3.11 via uv and symlink to /usr/local/bin for all users
ENV UV_PYTHON_INSTALL_DIR="/usr/local/share/uv/python"
RUN uv python install 3.11 && \
    ln -sf $(uv python find 3.11) /usr/local/bin/python3 && \
    ln -sf $(uv python find 3.11) /usr/local/bin/python

# Install Beads binary
RUN wget -q https://github.com/steveyegge/beads/releases/download/v${BEADS_VERSION}/beads_${BEADS_VERSION}_linux_amd64.tar.gz -O /tmp/beads.tar.gz && \
    tar xzf /tmp/beads.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/bd && \
    rm /tmp/beads.tar.gz

# Install Gastown binary
RUN wget -q https://github.com/steveyegge/gastown/releases/download/v${GASTOWN_VERSION}/gastown_${GASTOWN_VERSION}_linux_amd64.tar.gz -O /tmp/gastown.tar.gz && \
    tar xzf /tmp/gastown.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/gt && \
    rm /tmp/gastown.tar.gz

# Install Bun to system-wide location (accessible by all users including vscode)
ENV BUN_INSTALL="/usr/local"
RUN curl -fsSL https://bun.sh/install | bash

# Install Claude Code CLI for vscode user and symlink to system path
USER vscode
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
USER root
RUN ln -sf /home/vscode/.local/bin/claude /usr/local/bin/claude

# Install OpenAI Codex CLI globally (bun puts globals in $BUN_INSTALL/bin)
RUN bun install -g @openai/codex

# Install Wrangler (Cloudflare CLI) globally
RUN bun install -g wrangler

# Embed ai-coding-utils (slack notifications + beads hooks)
COPY lib/ai-coding-utils/slack /opt/ai-coding-utils/slack
COPY lib/ai-coding-utils/beads /opt/ai-coding-utils/beads

# Install Python dependencies for embedded libraries
RUN uv pip install --system --break-system-packages --python 3.11 \
    requests>=2.28.0 \
    pyyaml>=6.0 \
    watchdog>=3.0.0 \
    python-dotenv>=1.0.0

# Add ai-coding-utils to PYTHONPATH
ENV PYTHONPATH="/opt/ai-coding-utils"

# Embed Claude agent configurations for downstream projects
COPY lib/agent-configs/claude-agents/ /opt/agent-configs/claude-agents/

# Embed agent configs (GitHub Copilot workspace agents)
COPY lib/agent-configs/github-agents/ /opt/agent-configs/github-agents/

# Embed dev-infra (devcontainer components, secrets manager, project setup)
COPY lib/dev-infra/components/ /opt/dev-infra/
COPY lib/dev-infra/secrets /opt/dev-infra/secrets
COPY lib/dev-infra/setup /opt/dev-infra/setup
RUN chmod +x /opt/dev-infra/*.sh /opt/dev-infra/setup/*.sh \
    && chmod +x /opt/ai-coding-utils/beads/setup/ensure_beads.sh \
    && chmod +x /opt/dev-infra/setup/ensure_gastown.sh \
    && chmod +x /opt/dev-infra/setup/ensure_crew.sh \
    && chmod +x /opt/dev-infra/setup/start_gastown_services.sh \
    && chmod +x /opt/dev-infra/setup/start_beads_notifier.sh \
    && chmod +x /opt/dev-infra/setup/daemon_watchdog.sh

# Copy utility documentation and defaults into the image for downstream layering
COPY docs/UTILITIES.md /usr/local/share/image-docs/UTILITIES.md
COPY docs/.gitattributes /usr/local/share/image-docs/.gitattributes
COPY docs/CLAUDE.md /usr/local/share/image-docs/CLAUDE.md
COPY docs/crew.json /usr/local/share/image-docs/crew.json

# Copy auto-source script
COPY ai-dev-utils.sh /etc/profile.d/ai-dev-utils.sh
RUN chmod +x /etc/profile.d/ai-dev-utils.sh

# Source ai-dev-utils.sh from bash.bashrc so non-login interactive shells get functions too
RUN echo '' >> /etc/bash.bashrc && \
    echo '# Source AI dev utilities for all interactive shells' >> /etc/bash.bashrc && \
    echo 'if [ -f /etc/profile.d/ai-dev-utils.sh ]; then' >> /etc/bash.bashrc && \
    echo '    . /etc/profile.d/ai-dev-utils.sh' >> /etc/bash.bashrc && \
    echo 'fi' >> /etc/bash.bashrc

# Copy and run test script
COPY test-tools.sh /usr/local/bin/test-tools.sh
RUN chmod +x /usr/local/bin/test-tools.sh && \
    /usr/local/bin/test-tools.sh

# Validate tools are accessible as the vscode user (catches permission issues)
USER vscode
RUN /usr/local/bin/test-tools.sh
USER root

# Bake devcontainer metadata into image for VS Code extensions
LABEL devcontainer.metadata='[{ \
  "remoteUser": "vscode", \
  "containerEnv": { \
    "CLAUDE_CONFIG_DIR": "/home/vscode/.claude" \
  }, \
  "mounts": [ \
	"source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind", \
    "source=claude-code-config-${localWorkspaceFolderBasename},target=/home/vscode/.claude,type=volume", \
    "source=gastown-data-${localWorkspaceFolderBasename},target=/home/vscode/gt,type=volume", \
    "source=shared-gh-auth,target=/home/vscode/.shared-auth/gh,type=volume", \
    "source=shared-claude-auth,target=/home/vscode/.shared-auth/claude,type=volume" \
  ], \
  "customizations": { \
    "vscode": { \
      "extensions": [ \
        "ms-azuretools.vscode-docker", \
        "ms-python.python", \
        "charliermarsh.ruff", \
        "RooVeterinaryInc.roo-cline", \
        "sourcegraph.amp", \
        "Anthropic.claude-code", \
        "openai.chatgpt" \
      ], \
      "settings": { \
        "npm.packageManager": "bun" \
      } \
    } \
  }, \
  "postCreateCommand": "cp /usr/local/share/image-docs/UTILITIES.md .devcontainer/UTILITIES.md 2>/dev/null || true; [ ! -f .gitattributes ] && cp /usr/local/share/image-docs/.gitattributes .gitattributes 2>/dev/null || true; [ ! -f CLAUDE.md ] && cp /usr/local/share/image-docs/CLAUDE.md CLAUDE.md 2>/dev/null || true; [ ! -f .devcontainer/crew.json ] && cp /usr/local/share/image-docs/crew.json .devcontainer/crew.json 2>/dev/null || true; /opt/ai-coding-utils/beads/setup/ensure_beads.sh; /opt/dev-infra/setup/ensure_gastown.sh; /opt/dev-infra/setup/ensure_crew.sh; /opt/dev-infra/setup/install-agents.sh", \
  "postStartCommand": "/opt/dev-infra/setup/start_gastown_services.sh; /opt/dev-infra/setup/start_beads_notifier.sh" \
}]'

# Set working directory
WORKDIR /workspace

# Default shell
CMD ["/bin/bash"]
