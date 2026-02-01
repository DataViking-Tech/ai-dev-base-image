FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Build arguments for component versions
ARG AI_CODING_UTILS_VERSION=v1.0.5
ARG DEV_INFRA_VERSION=v1.0.6
ARG BEADS_VERSION=0.49.2

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    build-essential \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

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

# Install Claude CLI to system-wide location (accessible by all users including vscode)
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    cp -L /root/.local/bin/claude /usr/local/bin/claude && \
    chmod +x /usr/local/bin/claude

# Install Beads binary with checksum verification
RUN BEADS_SHA256="32a79c3250e5f32fa847068d7574eed4b6664663033bf603a8f393680b03237b" && \
    wget -q https://github.com/steveyegge/beads/releases/download/v${BEADS_VERSION}/beads_${BEADS_VERSION}_linux_amd64.tar.gz -O /tmp/beads.tar.gz && \
    echo "${BEADS_SHA256}  /tmp/beads.tar.gz" | sha256sum -c - && \
    tar xzf /tmp/beads.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/bd && \
    rm /tmp/beads.tar.gz

# Install Bun to system-wide location (accessible by all users including vscode)
ENV BUN_INSTALL="/usr/local"
RUN curl -fsSL https://bun.sh/install | bash

# Install OpenAI Codex CLI globally (bun puts globals in $BUN_INSTALL/bin)
RUN bun install -g @openai/codex

# Clone and embed ai-coding-utils (with authentication for private repo)
RUN --mount=type=secret,id=github_token \
    if [ -f /run/secrets/github_token ]; then \
        export GH_TOKEN=$(cat /run/secrets/github_token); \
        git clone --depth 1 --branch ${AI_CODING_UTILS_VERSION} \
            https://x-access-token:${GH_TOKEN}@github.com/DataViking-Tech/ai-coding-utils.git /tmp/ai-coding-utils; \
    else \
        git clone --depth 1 --branch ${AI_CODING_UTILS_VERSION} \
            https://github.com/DataViking-Tech/ai-coding-utils.git /tmp/ai-coding-utils; \
    fi && \
    mkdir -p /opt/ai-coding-utils && \
    cp -r /tmp/ai-coding-utils/slack /opt/ai-coding-utils/ && \
    cp -r /tmp/ai-coding-utils/beads /opt/ai-coding-utils/ && \
    rm -rf /tmp/ai-coding-utils

# Install ai-coding-utils Python dependencies via uv
RUN uv pip install --system --break-system-packages --python 3.11 \
    requests \
    pyyaml \
    watchdog>=3.0.0 \
    requests>=2.28.0 \
    pyyaml>=6.0 \
    python-dotenv>=1.0.0

# Add ai-coding-utils to PYTHONPATH
ENV PYTHONPATH="/opt/ai-coding-utils"

# Clone and embed dev-infra components (with authentication for private repo)
RUN --mount=type=secret,id=github_token \
    if [ -f /run/secrets/github_token ]; then \
        export GH_TOKEN=$(cat /run/secrets/github_token); \
        git clone --depth 1 --branch ${DEV_INFRA_VERSION} \
            https://x-access-token:${GH_TOKEN}@github.com/DataViking-Tech/dev-infra.git /tmp/dev-infra; \
    else \
        git clone --depth 1 --branch ${DEV_INFRA_VERSION} \
            https://github.com/DataViking-Tech/dev-infra.git /tmp/dev-infra; \
    fi && \
    mkdir -p /opt/dev-infra && \
    cp -r /tmp/dev-infra/devcontainer/components/* /opt/dev-infra/ && \
    cp -r /tmp/dev-infra/secrets /opt/dev-infra/ && \
    chmod +x /opt/dev-infra/*.sh && \
    rm -rf /tmp/dev-infra

# Copy utility documentation into the image for downstream layering
COPY docs/UTILITIES.md /usr/local/share/image-docs/UTILITIES.md

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
      ] \
    } \
  }, \
  "postCreateCommand": "cp /usr/local/share/image-docs/UTILITIES.md .devcontainer/UTILITIES.md 2>/dev/null || true" \
}]'

# Set working directory
WORKDIR /workspace

# Default shell
CMD ["/bin/bash"]
