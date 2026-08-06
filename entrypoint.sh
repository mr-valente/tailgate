#!/usr/bin/env sh

# Fail on any error
set -e

# TUN device for tailscaled. Defaults to userspace networking.
# Set TAILSCALE_TUN to a device name (e.g. tailscale0) for kernel mode,
# or to an empty string to omit --tun and use Tailscale's default.
# ${TAILSCALE_TUN+x} is empty only when the variable is unset (not when empty).
if [ -z "${TAILSCALE_TUN+x}" ]; then
  TAILSCALE_TUN="userspace-networking"
fi

if [ -n "$TAILSCALE_TUN" ]; then
  TAILSCALE_TUN_ARG="--tun=$TAILSCALE_TUN"
else
  TAILSCALE_TUN_ARG=""
fi

# Start tailscaled and wait for it to come up
tailscaled \
  --state=/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock \
  $TAILSCALE_TUN_ARG \
  &
sleep 5

# Set up MagicDNS
cat <<EOF > /etc/resolv.conf
nameserver 100.100.100.100
nameserver 127.0.0.11
search ${TAILNET_NAME} local
options ndots:0
EOF

# Set default hostname if not provided
if [ -z "${TAILSCALE_HOSTNAME}" ]; then
  TAILSCALE_HOSTNAME="tailgate"
fi

# Log in to Tailscale if not already logged in
if tailscale status 2>/dev/null | grep -q '100\.'; then
  echo "Tailscale is already logged in. Skipping 'tailscale up'."
else
  echo "Tailscale not logged in. Using auth key..."
  if [ -n "${TAILSCALE_AUTHKEY}" ]; then
    tailscale up --authkey="${TAILSCALE_AUTHKEY}" \
                 --hostname="${TAILSCALE_HOSTNAME}"
  else
    echo "WARNING: No auth key provided; skipping tailscale up."
  fi
fi

# Start Sablier if requested (in background)
# The -with-sablier image sets INCLUDE_SABLIER=true at build time.
INCLUDE_SABLIER=${INCLUDE_SABLIER:-false}
SABLIER_VERSION=${SABLIER_VERSION:-1.10.1}

if [ "$INCLUDE_SABLIER" = "true" ]; then
  echo "Downloading Sablier v${SABLIER_VERSION}..."

  curl -L "https://github.com/sablierapp/sablier/releases/download/v${SABLIER_VERSION}/sablier-${SABLIER_VERSION}-linux-amd64.tar.gz" \
    -o /tmp/sablier.tar.gz \
    && tar -xzf /tmp/sablier.tar.gz -C /tmp \
    && mv /tmp/sablier /usr/bin/sablier \
    && chmod +x /usr/bin/sablier \
    && rm -f /tmp/sablier.tar.gz
    
  echo "Sablier installed successfully."
  
  echo "Starting Sablier..."
  sablier start --configFile=/etc/sablier/sablier.yml &
  sleep 2
else
  echo "Sablier disabled; skipping download and startup."
fi

# Run caddy (in foreground with exec)
if [ -f /etc/caddy/Caddyfile ]; then
  # Use the Caddyfile in the /etc/caddy directory if it exists
  if [ "${CADDY_WATCH}" = "true" ]; then
    echo "Running with Caddyfile watch enabled..."
    exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile --watch
  else
    echo "Running without Caddyfile watch enabled..."
    exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
  fi
else
  # Otherwise, run without a config
  echo "Running without a Caddyfile..."
  exec caddy run
fi
