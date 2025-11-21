# Tailgate

**Secure, zero-config ingress using [Tailscale](https://tailscale.com/) and [Caddy](https://caddyserver.com/).**

Tailgate allows you to expose containerized services privately over your Tailnet with automatic HTTPS. It bundles Tailscale, Caddy, and popular plugins into a single, easy-to-deploy container.

## Features

- **Private Ingress**: Expose services securely via Tailscale without opening public ports.
- **Automatic HTTPS**: Caddy manages certificates automatically.
- **Plugin Support**: Includes Cloudflare DNS support out-of-the-box.
- **Sablier Integration**: Optional support for [Sablier](https://sablierapp.dev/) to scale containers on demand (Scale-to-Zero).

## Available Images

| Image Tag | Description |
|-----------|-------------|
| `valentemath/tailgate:latest` | Base image. Includes Tailscale, Caddy, and Cloudflare DNS plugin. |
| `valentemath/tailgate:latest-with-sablier` | Includes the **Sablier Caddy plugin**. The Sablier binary is downloaded automatically at runtime. |

## Quick Start

The recommended way to run Tailgate is via Docker Compose.

### 1. Configure `docker-compose.yaml`

```yaml
services:
  tailgate:
    image: valentemath/tailgate:latest
    container_name: tailgate
    environment:
      - TAILSCALE_AUTHKEY=tskey-auth-kB...  # Required
      - TAILSCALE_HOSTNAME=tailgate         # Optional
      - CLOUDFLARE_API_TOKEN=...            # Optional (if using DNS challenges)
    volumes:
      - tailscale-state:/tailscale          # Persist Tailscale identity
      - ./Caddyfile:/etc/caddy/Caddyfile    # Mount your config
      - caddy-data:/data                    # Persist Caddy certificates

volumes:
  tailscale-state:
  caddy-data:
```

### 2. Create a `Caddyfile`

Create a `Caddyfile` in the same directory. Tailgate will serve this configuration over your Tailnet.

```caddyfile
# Example: Reverse proxy a service on your Tailnet
machine-name.tailnet-name.ts.net {
    reverse_proxy other-container:80
}
```

### 3. Deploy

```bash
docker compose up -d
```

## Configuration

### Tailscale
| Variable | Description | Default |
|----------|-------------|---------|
| `TAILSCALE_AUTHKEY` | **Required**. Your [Tailscale Auth Key](https://tailscale.com/kb/1085/auth-keys/). | - |
| `TAILSCALE_HOSTNAME` | The hostname for this node on your Tailnet. | `tailgate` |
| `TAILNET_NAME` | Your Tailnet name (required for some MagicDNS setups). | - |

### Caddy
| Variable | Description | Default |
|----------|-------------|---------|
| `CADDY_WATCH` | Set to `true` to auto-reload Caddy when the Caddyfile changes. | `false` |
| `CADDY_PORT` | The port for Caddy's admin API (used for healthchecks). | `2019` |
| `CLOUDFLARE_API_TOKEN`| Token for Cloudflare DNS challenges. | - |

### Sablier (Scale-to-Zero)
*Only applicable when using the `latest-with-sablier` image.*

| Variable | Description | Default |
|----------|-------------|---------|
| `INCLUDE_SABLIER` | Set to `true` to download and start the Sablier binary. | `true` |
| `SABLIER_VERSION` | The version of Sablier to download. | `1.10.1` |
| `SABLIER_PORT` | The port Sablier listens on. | `10000` |

**Note on Sablier:**
When using the `-with-sablier` image, the Sablier binary is **downloaded at runtime** if `INCLUDE_SABLIER` is set to `true`. You must mount a configuration file to `/etc/sablier/sablier.yml` and provide access to the Docker socket.

```yaml
services:
  tailgate:
    image: valentemath/tailgate:latest-with-sablier
    volumes:
      - ./sablier.yml:/etc/sablier/sablier.yml
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

## Building Custom Images

If you need Caddy plugins other than Cloudflare or Sablier, you can build your own image using the provided `Dockerfile`.

1.  **Clone the repository.**
2.  **Modify `docker-compose.yaml`**:
    Update the `PLUGINS` build argument to include the Go import paths of the plugins you need.
    ```yaml
    build:
      context: .
      args:
        PLUGINS: "github.com/caddy-dns/duckdns github.com/caddy-dns/route53"
    ```
3.  **Build and Run**:
    ```bash
    docker compose up -d --build
    ```


## Credits

- [Tailscale](https://tailscale.com)
- [Caddy](https://caddyserver.com)
- [Sablier](https://sablierapp.dev)
