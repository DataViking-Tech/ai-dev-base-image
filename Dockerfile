FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Build arguments for component versions
ARG AI_CODING_UTILS_VERSION=v1.0.5
ARG DEV_INFRA_VERSION=v1.0.4
ARG BEADS_VERSION=0.49.2

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    python3 \
    python3-venv \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install uv (Python package manager) to system-wide location
ENV UV_INSTALL_DIR="/usr/local/bin"
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Remove PEP 668 EXTERNALLY-MANAGED marker to allow uv to manage system Python
RUN rm -f /usr/lib/python*/EXTERNALLY-MANAGED

# Install Claude CLI and move to system-wide location (accessible by all users including vscode)
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    mv /root/.local/bin/claude /usr/local/bin/claude

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

# Install OpenAI Codex CLI globally
RUN /usr/local/bin/bun install -g @openai/codex
ENV PATH="/usr/local/bin:$PATH"

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
RUN uv pip install --system requests pyyaml

# Add ai-coding-utils to PYTHONPATH
ENV PYTHONPATH="/opt/ai-coding-utils:${PYTHONPATH}"

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

# Copy auto-source script
COPY ai-dev-utils.sh /etc/profile.d/ai-dev-utils.sh
RUN chmod +x /etc/profile.d/ai-dev-utils.sh

# Copy and run test script
COPY test-tools.sh /usr/local/bin/test-tools.sh
RUN chmod +x /usr/local/bin/test-tools.sh && \
    /usr/local/bin/test-tools.sh

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
  } \
}]'

# Set working directory
WORKDIR /workspace

# Default shell
CMD ["/bin/bash"]
