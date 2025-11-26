# syntax=docker/dockerfile:1

################################################################################
# Stage 1: Builder
# Builds Caddy with optional plugins using xcaddy
################################################################################

FROM debian:trixie AS builder

# Golang version for building Caddy
ARG GOLANG_VERSION=1.25.3

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
        debian-keyring \
        debian-archive-keyring \
        apt-transport-https \
        build-essential \
        gcc \
        file \
        procps \
        ruby \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Download and install Golang
RUN wget https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz \
  && tar -C /usr/local -xzf go${GOLANG_VERSION}.linux-amd64.tar.gz \
  && rm go${GOLANG_VERSION}.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:$PATH"

# Install xcaddy for building Caddy with plugins
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-xcaddy-archive-keyring.gpg \
 && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-xcaddy.list \
 && apt-get update \
 && apt-get install -y xcaddy \
 && rm -rf /var/lib/apt/lists/*

# Optional space-separated list of Caddy plugins to include
ARG PLUGINS=""

# Build Caddy with or without plugins
RUN if [ -n "$PLUGINS" ]; then \
    echo "Building custom caddy with plugins: $PLUGINS"; \
    PLUGIN_ARGS=""; \
    for plugin in $PLUGINS; do \
      PLUGIN_ARGS="$PLUGIN_ARGS --with $plugin"; \
    done; \
    xcaddy build $PLUGIN_ARGS; \
  else \
    echo "No plugins specified. Building default caddy"; \
    xcaddy build; \
  fi
  

################################################################################
# Stage 2: Runtime
# Minimal Debian image with Tailscale, Caddy, and optionally Sablier
################################################################################

FROM debian:trixie

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      iptables \
      ca-certificates \
      curl \
      vim \
      libc6 \
      jq \
      # Uncomment for debugging:
      # iputils-ping \
      # dnsutils \
      # openresolv \
      # file \
    && rm -rf /var/lib/apt/lists/*

# Install Tailscale from official repository
RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null \
 && curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends tailscale \
 && rm -rf /var/lib/apt/lists/*

# Sablier version, passed via build-arg
ARG SABLIER_VERSION
ENV SABLIER_VERSION=${SABLIER_VERSION}

# Copy Caddy binary from builder stage
COPY --from=builder /caddy /usr/bin/caddy

# Copy entrypoint and healthcheck scripts
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh /healthcheck.sh

ENTRYPOINT ["/entrypoint.sh"]
