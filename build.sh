#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

LATEST_TAILSCALE_RELEASE_URL="https://github.com/tailscale/tailscale/releases/latest"
LATEST_SABLIER_RELEASE_URL="https://github.com/sablierapp/sablier/releases/latest"

# Default values
TAILSCALE_VERSION=""
SABLIER_VERSION=""
IMAGE_NAME="valentemath/tailgate"

normalize_version() {
    local version="$1"
    echo "${version#v}"
}

resolve_latest_release_version() {
    local release_url="$1"
    local component_name="$2"
    local resolved_url
    local tag_name

    resolved_url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$release_url") || {
        echo "Failed to resolve latest $component_name release from $release_url" >&2
        exit 1
    }

    tag_name="${resolved_url##*/}"

    if [[ -z "$tag_name" || "$tag_name" == "latest" ]]; then
        echo "Failed to parse latest $component_name release tag from $resolved_url" >&2
        exit 1
    fi

    normalize_version "$tag_name"
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --tailscale)
            if [[ -n "${2:-}" && "${2:-}" != --* ]]; then
                TAILSCALE_VERSION="$2"
                shift
            fi
            ;;
        --tailscale=*) TAILSCALE_VERSION="${1#*=}" ;;
        --sablier)
            if [[ -n "${2:-}" && "${2:-}" != --* ]]; then
                SABLIER_VERSION="$2"
                shift
            fi
            ;;
        --sablier=*) SABLIER_VERSION="${1#*=}" ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -n "$TAILSCALE_VERSION" ]]; then
    TAILSCALE_VERSION=$(normalize_version "$TAILSCALE_VERSION")
else
    TAILSCALE_VERSION=$(resolve_latest_release_version "$LATEST_TAILSCALE_RELEASE_URL" "Tailscale")
fi

if [[ -n "$SABLIER_VERSION" ]]; then
    SABLIER_VERSION=$(normalize_version "$SABLIER_VERSION")
else
    SABLIER_VERSION=$(resolve_latest_release_version "$LATEST_SABLIER_RELEASE_URL" "Sablier")
fi

TAG_VERSION="$TAILSCALE_VERSION"
TAG_LATEST="latest"
TAG_LATEST_SABLIER="latest-with-sablier"
TAG_VERSION_SABLIER="$TAILSCALE_VERSION-with-sablier"

echo "Building Docker images with Tailscale version $TAILSCALE_VERSION and Sablier version $SABLIER_VERSION..."
sudo docker compose build --build-arg TAILSCALE_VERSION="$TAILSCALE_VERSION" --build-arg SABLIER_VERSION="$SABLIER_VERSION"

echo "Tagging images with version $TAG_VERSION..."
sudo docker tag "$IMAGE_NAME:$TAG_LATEST" "$IMAGE_NAME:$TAG_VERSION"
sudo docker tag "$IMAGE_NAME:$TAG_LATEST_SABLIER" "$IMAGE_NAME:$TAG_VERSION_SABLIER"

echo "Pushing images to registry..."
# Push in parallel for efficiency using background processes
sudo docker push "$IMAGE_NAME:$TAG_LATEST" &
sudo docker push "$IMAGE_NAME:$TAG_VERSION" &
sudo docker push "$IMAGE_NAME:$TAG_LATEST_SABLIER" &
sudo docker push "$IMAGE_NAME:$TAG_VERSION_SABLIER" &

# Wait for all background jobs to complete
wait

echo "✓ Successfully built and pushed version $TAG_VERSION"
echo "Images pushed:"
echo "  - $IMAGE_NAME:$TAG_LATEST"
echo "  - $IMAGE_NAME:$TAG_VERSION"
echo "  - $IMAGE_NAME:$TAG_LATEST_SABLIER"
echo "  - $IMAGE_NAME:$TAG_VERSION_SABLIER"
echo "Resolved component versions:"
echo "  - Tailscale: $TAILSCALE_VERSION"
echo "  - Sablier: $SABLIER_VERSION"
