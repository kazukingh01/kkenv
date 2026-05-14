FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    sudo \
    ca-certificates \
    jq \
    locales \
    less \
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
    && rm -rf /var/lib/apt/lists/*

# Install Rust (latest stable)
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

# Install Python + browser-use CLI + Chromium (for browser automation tasks)
RUN apt-get update -qq && apt-get install -y -qq \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*
ENV BROWSER_USE_VENV=/opt/browser-use-venv
RUN python3 -m venv ${BROWSER_USE_VENV} \
    && ${BROWSER_USE_VENV}/bin/pip install --no-cache-dir browser-use-cli
ENV PATH=${BROWSER_USE_VENV}/bin:$PATH
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
RUN ${BROWSER_USE_VENV}/bin/playwright install --with-deps chromium \
    && chmod -R a+rX /opt/ms-playwright

# Install edge-tts (Microsoft Edge online TTS, no API key needed) in its own venv
ENV EDGE_TTS_VENV=/opt/edge-tts-venv
RUN python3 -m venv ${EDGE_TTS_VENV} \
    && ${EDGE_TTS_VENV}/bin/pip install --no-cache-dir edge-tts==7.2.8
ENV PATH=${EDGE_TTS_VENV}/bin:$PATH

# ffmpeg for WAV transcoding (edge-tts only outputs MP3)
RUN apt-get update -qq && apt-get install -y -qq ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with sudo privileges
RUN useradd -m -s /bin/bash claude \
    && echo 'claude ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/claude

# Set up claude settings for all permissions
RUN mkdir -p /home/claude/.claude/skills && \
    echo '{"permissions":{"allow":["*"],"deny":[]}}' > /home/claude/.claude/settings.json && \
    chown -R claude:claude /home/claude/.claude

# Runtime env vars (passed via --env or --env-file; see .env.example)
ENV DISCORD_WEBHOOK_URL=""
ENV DISCORD_MENTION=""

# Install helper scripts to /usr/local/bin so they're on PATH for all users
COPY scripts/notify-discord.sh /usr/local/bin/notify-discord.sh
COPY scripts/tts.sh /usr/local/bin/tts.sh
RUN chmod +x /usr/local/bin/notify-discord.sh /usr/local/bin/tts.sh

WORKDIR /workspace
RUN chown claude:claude /workspace

USER claude

# Install Claude Code via native installer (supports `claude --update` / self-update)
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH=/home/claude/.local/bin:$PATH

RUN echo 'alias claude="claude --dangerously-skip-permissions"' >> /home/claude/.bashrc
