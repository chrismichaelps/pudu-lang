#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
image="pudu-site-builder:local"

docker build --platform linux/amd64 -f "$root/website/platform/vercel/Dockerfile" -t "$image" "$root"
docker run --rm --platform linux/amd64 -v "$root/website/bin:/output" "$image"
file "$root/website/bin/pudu-site-server-linux-x64"
