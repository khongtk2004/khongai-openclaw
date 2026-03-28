# KhongAI - OpenClaw with Telegram Bot Integration
FROM node:22-bookworm

LABEL org.opencontainers.image.source="https://github.com/khongtk2004/khongai-openclaw"
LABEL org.opencontainers.image.description="KhongAI - OpenClaw with Telegram Bot Admin Control"
LABEL org.opencontainers.image.licenses="MIT"
LABEL khongai.version="1.0.0"
LABEL khongai.features="telegram-bot,ollama,openclaw"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    unzip \
    build-essential \
    procps \
    file \
    sudo \
    jq \
    wget \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Install Homebrew
RUN groupadd -f linuxbrew && \
    useradd -m -s /bin/bash -g linuxbrew linuxbrew && \
    echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    mkdir -p /home/linuxbrew/.linuxbrew && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew/.linuxbrew

RUN mkdir -p /home/linuxbrew/.linuxbrew/Homebrew && \
    git clone --depth 1 https://github.com/Homebrew/brew /home/linuxbrew/.linuxbrew/Homebrew && \
    mkdir -p /home/linuxbrew/.linuxbrew/bin && \
    ln -s /home/linuxbrew/.linuxbrew/Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew/.linuxbrew && \
    chmod -R g+rwX /home/linuxbrew/.linuxbrew
    
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_NO_AUTO_UPDATE=1
ENV HOMEBREW_NO_INSTALL_CLEANUP=1

# Enable corepack
RUN corepack enable

WORKDIR /app

# Clone and build OpenClaw
ARG OPENCLAW_VERSION=main
RUN git clone --depth 1 --branch ${OPENCLAW_VERSION} https://github.com/openclaw/openclaw.git . && \
    echo "Building OpenClaw from branch: ${OPENCLAW_VERSION}" && \
    git rev-parse HEAD > /app/openclaw-commit.txt

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
RUN npm_config_script_shell=bash pnpm ui:install
RUN npm_config_script_shell=bash pnpm ui:build

# Clean up
RUN rm -rf .git node_modules/.cache

# Create admin bot configuration directory
RUN mkdir -p /app/admin-bot

# Create app user
RUN mkdir -p /home/node/.khongai /home/node/.khongai/workspace /home/node/.khongai/logs \
    && chown -R node:node /home/node /app \
    && chmod -R 755 /home/node/.khongai \
    && usermod -aG linuxbrew node \
    && chmod -R g+w /home/linuxbrew/.linuxbrew \
    && chown -R node:node /usr/local/lib/node_modules \
    && chown -R node:node /usr/local/bin

# Install Playwright dependencies
RUN npx -y playwright@latest install-deps chromium

USER node

# Install Playwright browsers
RUN npx -y playwright@latest install chromium

WORKDIR /home/node

ENV NODE_ENV=production
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/app/node_modules/.bin:${PATH}"
ENV HOMEBREW_NO_AUTO_UPDATE=1
ENV HOMEBREW_NO_INSTALL_CLEANUP=1

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

# Copy startup script
COPY scripts/start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Copy admin bot
COPY config/telegram-admin-bot.js /app/admin-bot/

ENTRYPOINT ["/app/start.sh"]