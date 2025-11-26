#!/bin/bash

# gh release view -R sablierapp/sablier --json tagName --jq '.tagName | ltrimstr("v")'

set -e  # Exit immediately if a command exits with a non-zero status

# Default values
TAILSCALE_VERSION=""
SABLIER_VERSION=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --tailscale) TAILSCALE_VERSION="$2"; shift ;;
        --sablier) SABLIER_VERSION="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if tailscale version is provided
if [ -z "$TAILSCALE_VERSION" ]; then
    echo "Error: Tailscale version is required"
    echo "Usage: ./build.sh --tailscale <version> [--sablier <version>]"
    echo "Example: ./build.sh --tailscale 1.86.2 --sablier 1.10.1"
    exit 1
fi

VERSION=$TAILSCALE_VERSION

# Validate version format (basic semver check)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Warning: Version '$VERSION' doesn't follow semver format (x.y.z)"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Building Docker images with Sablier version $SABLIER_VERSION..."
sudo docker compose build --build-arg SABLIER_VERSION=$SABLIER_VERSION

echo "Tagging images with version $VERSION..."
sudo docker tag valentemath/tailgate:latest valentemath/tailgate:$VERSION
sudo docker tag valentemath/tailgate:latest-with-sablier valentemath/tailgate:$VERSION-with-sablier

echo "Pushing images to registry..."
# Push in parallel for efficiency using background processes
sudo docker push valentemath/tailgate:latest &
sudo docker push valentemath/tailgate:$VERSION &
sudo docker push valentemath/tailgate:latest-with-sablier &
sudo docker push valentemath/tailgate:$VERSION-with-sablier &

# Wait for all background jobs to complete
wait

echo "✓ Successfully built and pushed version $VERSION"
echo "Images pushed:"
echo "  - valentemath/tailgate:latest"
echo "  - valentemath/tailgate:$VERSION"
echo "  - valentemath/tailgate:latest-with-sablier"
echo "  - valentemath/tailgate:$VERSION-with-sablier"