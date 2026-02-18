FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

# Optionally install Chromium and Xvfb for browser automation.
# Build with: docker build --build-arg OPENCLAW_INSTALL_BROWSER=1 ...
# Adds ~300MB but eliminates the 60-90s Playwright install on every container start.
# Must run after pnpm install so playwright-core is available in node_modules.
ARG OPENCLAW_INSTALL_BROWSER=""
RUN if [ -n "$OPENCLAW_INSTALL_BROWSER" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && \
      node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY . .
RUN pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# Install helper CLIs (gog, wacli) into the container.
# gog: build from source (per upstream docs). wacli: Go module install.
ARG GOGCLI_REF=2df8ece2f629
ARG WACLI_VERSION=v0.2.0
ARG GO_VERSION=1.24.4
USER root
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git make ca-certificates && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tgz && \
    tar -C /usr/local -xzf /tmp/go.tgz && \
    git clone https://github.com/steipete/gogcli.git /tmp/gogcli && \
    cd /tmp/gogcli && \
    git checkout "${GOGCLI_REF}" && \
    PATH="/usr/local/go/bin:${PATH}" make && \
    install -m 0755 ./bin/gog /usr/local/bin/gog && \
    GOBIN=/usr/local/bin /usr/local/go/bin/go install github.com/steipete/wacli/cmd/wacli@"${WACLI_VERSION}" && \
    mkdir -p /home/ubuntu/go/bin && \
    ln -sf /usr/local/bin/wacli /home/ubuntu/go/bin/wacli && \
    rm -rf /tmp/gogcli /tmp/go.tgz /usr/local/go && \
    apt-get purge -y git make && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /root/go

ENV NODE_ENV=production

# Allow non-root user to write temp files during runtime/tests.
RUN chown -R node:node /app

# Security hardening: Run as non-root user
# The node:22-bookworm image includes a 'node' user (uid 1000)
# This reduces the attack surface by preventing container escape via root privileges
USER node

# Start gateway server with default config.
# Binds to loopback (127.0.0.1) by default for security.
#
# For container platforms requiring external health checks:
#   1. Set OPENCLAW_GATEWAY_TOKEN or OPENCLAW_GATEWAY_PASSWORD env var
#   2. Override CMD: ["node","openclaw.mjs","gateway","--allow-unconfigured","--bind","lan"]
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
