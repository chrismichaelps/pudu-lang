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
# `find` rather than a tool that has to be installed. Building the catalogue is
# a step somebody runs on a machine that has the compiler, and requiring a
# search tool as well is a dependency the build does not need.
find "$root/packages/pudu/v0.1/lib" -name '*.pudu' -type f | sort > "$sources"
xargs "$compiler" doc --json < "$sources" > "$raw"
xargs "$compiler" api --json < "$sources" > "$public"
node "$root/website/scripts/normalize-catalog.mjs" "$raw" "$public" "$clean"
mv "$clean" "$output"
