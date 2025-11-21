#!/usr/bin/env sh

# Fail on any error
set -e

# Start tailscaled and wait for it to come up
tailscaled \
  --state=/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock \
  --tun=userspace-networking \
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
# Default to true if INCLUDE_SABLIER is not set
INCLUDE_SABLIER=${INCLUDE_SABLIER:-true}
SABLIER_VERSION=${SABLIER_VERSION:-1.10.1}

if [ "$INCLUDE_SABLIER" = "true" ]; then
  echo "Downloading Sablier v${SABLIER_VERSION}..."
  curl -L "https://github.com/sablierapp/sablier/releases/download/v${SABLIER_VERSION}/sablier_${SABLIER_VERSION}_linux-amd64" \
    -o /usr/bin/sablier \
    && chmod +x /usr/bin/sablier
  echo "Sablier installed successfully."
  
  echo "Starting Sablier..."
  sablier start --configFile=/etc/sablier/sablier.yml &
  sleep 2
fi

# Run caddy (in foreground with exec)
if [ -f /etc/caddy/Caddyfile ]; then
  # Use the Caddyfile in the /etc/caddy directory if it exists
  if [ "${CADDY_WATCH}" = "true" ]; then
    exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile --watch
  else
    exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
  fi
else
  # Otherwise, run without a config
  exec caddy run
fi
