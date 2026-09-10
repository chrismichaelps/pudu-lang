#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
server="$root/website/bin/pudu-site-server-linux-x64"
local_server="${PUDU_STATIC_SERVER:-$root/website/bin/pudu-site-server-macos}"
output="$root/website/.vercel/output"
function_dir="$output/functions/index.func"

if [[ ! -x "$server" ]] || ! file "$server" | grep -q 'ELF 64-bit.*x86-64'; then
  echo "missing Linux x86-64 Pudu server: run website/scripts/build-linux-renderer.sh" >&2
  exit 1
fi
if [[ ! -x "$local_server" ]] || [[ -z "${PUDU_SITE_URL:-}" ]]; then
  echo "set PUDU_SITE_URL and provide a local Pudu server with PUDU_STATIC_SERVER" >&2
  exit 1
fi

rm -rf "$output"
mkdir -p "$function_dir" "$output/static/assets" "$output/static/fonts"
cp "$server" "$function_dir/pudu-site-server"
cp "$root/website/data/api.json" "$function_dir/api.json"
cp "$root/website/platform/vercel/index.js" "$function_dir/index.js"
cp "$root/website/public/site.css" "$output/static/assets/site.css"
cp "$root/website/public/assets/"* "$output/static/assets/"
cp "$root/website/public/fonts/"* "$output/static/fonts/"
chmod +x "$function_dir/pudu-site-server"

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
  '  "architecture": "x64",' \
  '  "maxDuration": 60' \
  '}' > "$function_dir/.vc-config.json"

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
  '    { "src": "/.*", "dest": "/index" }' \
  '  ]' \
  '}' > "$output/config.json"

echo "Built $output"
