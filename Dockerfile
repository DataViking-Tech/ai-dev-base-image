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
    python3-pip \
    python3-venv \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Claude CLI (official installation method - using trusted https://claude.ai source)
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install Beads binary with checksum verification
RUN BEADS_SHA256="32a79c3250e5f32fa847068d7574eed4b6664663033bf603a8f393680b03237b" && \
    wget -q https://github.com/steveyegge/beads/releases/download/v${BEADS_VERSION}/beads_${BEADS_VERSION}_linux_amd64.tar.gz -O /tmp/beads.tar.gz && \
    echo "${BEADS_SHA256}  /tmp/beads.tar.gz" | sha256sum -c - && \
    tar xzf /tmp/beads.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/bd && \
    rm /tmp/beads.tar.gz

# Clone and install ai-coding-utils
RUN git clone --depth 1 --branch ${AI_CODING_UTILS_VERSION} \
    https://github.com/DataViking-Tech/ai-coding-utils.git /tmp/ai-coding-utils && \
    pip3 install --no-cache-dir /tmp/ai-coding-utils && \
    rm -rf /tmp/ai-coding-utils

# Clone and embed dev-infra components
RUN git clone --depth 1 --branch ${DEV_INFRA_VERSION} \
    https://github.com/DataViking-Tech/dev-infra.git /tmp/dev-infra && \
    mkdir -p /opt/dev-infra && \
    cp -r /tmp/dev-infra/devcontainer/components/* /opt/dev-infra/ && \
    cp -r /tmp/dev-infra/secrets /opt/dev-infra/ && \
    chmod +x /opt/dev-infra/*.sh && \
    rm -rf /tmp/dev-infra

# Copy auto-source script
COPY ai-dev-utils.sh /etc/profile.d/ai-dev-utils.sh
RUN chmod +x /etc/profile.d/ai-dev-utils.sh

# Set working directory
WORKDIR /workspace

# Default shell
CMD ["/bin/bash"]
