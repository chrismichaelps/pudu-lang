#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
local_server="${PUDU_STATIC_SERVER:-$root/website/bin/pudu-site-server-macos}"
output="$root/website/.vercel/output"
function_dir="$output/functions/index.func"

if [[ ! -x "$local_server" ]] || [[ -z "${PUDU_SITE_URL:-}" ]]; then
  echo "set PUDU_SITE_URL and provide a local Pudu server with PUDU_STATIC_SERVER" >&2
  exit 1
fi

rm -rf "$output"
mkdir -p "$function_dir" "$output/static/assets" "$output/static/fonts"
cp "$root/website/data/api.json" "$function_dir/api.json"
cp "$root/website/platform/vercel/index.js" "$function_dir/index.js"
cp "$root/website/public/site.css" "$output/static/assets/site.css"
cp "$root/website/public/assets/"* "$output/static/assets/"
cp "$root/website/public/fonts/"* "$output/static/fonts/"
chmod 644 "$function_dir/api.json" "$function_dir/index.js" 2>/dev/null || true

node "$root/website/scripts/prerender.mjs" \
  "$local_server" \
  "$root/website/data/api.json" \
  "$output/static"

printf '%s\n' \
  '{' \
  '  "runtime": "nodejs22.x",' \
  '  "handler": "index.js",' \
  '  "launcherType": "Nodejs",' \
  '  "shouldAddHelpers": true,' \
  '  "architecture": "x86_64",' \
  '  "maxDuration": 60' \
  '}' > "$function_dir/.vc-config.json"

chmod 644 "$function_dir/.vc-config.json" 2>/dev/null || true

printf '%s\n' \
  '{' \
  '  "version": 3,' \
  '  "routes": [' \
  '    { "handle": "filesystem" },' \
  '    { "src": "/", "dest": "/index.html" },' \
  '    { "src": "/guide", "dest": "/guide/index.html" },' \
  '    { "src": "/about", "dest": "/about/index.html" },' \
  '    { "src": "/donate", "dest": "/donate/index.html" },' \
  '    { "src": "/modules", "dest": "/modules/index.html" },' \
  '    { "src": "/module/(.*)", "dest": "/module/$1/index.html" },' \
  '    { "src": "/docs/(.*)/(.*)/(.*)", "dest": "/docs/$1/$2/$3/index.html" },' \
  '    { "src": "/search", "dest": "/index" },' \
  '    { "src": "/.*", "dest": "/index" }' \
  '  ]' \
  '}' > "$output/config.json"

echo "Built $output"
