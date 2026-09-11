#!/usr/bin/env bash
set -euo pipefail

compiler="${1:-pudu}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
output="$root/website/data/api.json"

mkdir -p "$root/website/data"
raw="$(mktemp "$root/website/data/api.raw.XXXXXX")"
public="$(mktemp "$root/website/data/api.public.XXXXXX")"
clean="$(mktemp "$root/website/data/api.clean.XXXXXX")"
trap 'rm -f "$raw" "$public" "$clean"' EXIT

sources="$(mktemp "$root/website/data/api.sources.XXXXXX")"
trap 'rm -f "$raw" "$public" "$clean" "$sources"' EXIT
rg --files "$root/packages/pudu/v0.1/lib" -g '*.pudu' | sort > "$sources"
xargs "$compiler" doc --json < "$sources" > "$raw"
xargs "$compiler" api --json < "$sources" > "$public"
node "$root/website/scripts/normalize-catalog.mjs" "$raw" "$public" "$clean"
mv "$clean" "$output"
