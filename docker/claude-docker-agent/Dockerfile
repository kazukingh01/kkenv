FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies + GitHub CLI
RUN apt-get update && apt-get install -y \
    curl \
    git \
    sudo \
    ca-certificates \
    gpg \
    locales \
    less \
    jq \
    ripgrep \
    unzip \
    zip \
    vim \
    wget \
    tree \
&& mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y gh \
    && locale-gen ja_JP.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=ja_JP.UTF-8 \
    LC_ALL=ja_JP.UTF-8 \
    LESSCHARSET=utf-8

# Install build tools and libraries
RUN apt-get update -qq && apt-get install -y -qq \
    build-essential \
    pkg-config \
    libssl-dev \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install Rust (latest stable)
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

# Install Docker CLI only (daemon is on the host via socket mount)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with sudo privileges
RUN useradd -m -s /bin/bash claude \
    && echo 'claude ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/claude

# Set up claude settings for all permissions
RUN mkdir -p /home/claude/.claude/skills && \
    echo '{"permissions":{"allow":["*"],"deny":[]}}' > /home/claude/.claude/settings.json && \
    chown -R claude:claude /home/claude/.claude

# GH_TOKEN is passed from host at runtime via --env or --env-file
ENV GH_TOKEN=""

WORKDIR /workspace
RUN chown claude:claude /workspace

USER claude

RUN git config --global user.email "claude@example.com" \
    && git config --global user.name "Claude"

# Install Claude Code via native installer (supports `claude --update` / self-update)
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH=/home/claude/.local/bin:$PATH

RUN echo 'alias claude="claude --dangerously-skip-permissions"' >> /home/claude/.bashrc

COPY --chown=claude:claude docker-entrypoint.sh /home/claude/docker-entrypoint.sh
RUN chmod +x /home/claude/docker-entrypoint.sh

ENTRYPOINT ["/home/claude/docker-entrypoint.sh"]
