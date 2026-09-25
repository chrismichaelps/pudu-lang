#!/usr/bin/env bash
# Run the site on this machine and keep every open page showing what is on disk.
#
#   website/scripts/dev.sh
#
# Saving any Pudu source, documentation page, stylesheet, script, data file,
# or playground example starts the site again, and each open page follows: it
# reloads, or takes new styles in place when only a stylesheet changed. There
# is nothing to configure — `pudu run --watch` tells the site it is watched,
# and a site that is not watched serves exactly what it deploys.
#
# Environment, all optional:
#   PUDU            the compiler to run the site with (default: pudu on PATH)
#   PUDU_SITE_PORT  the port to listen on (default: 8080)
#   and any setting `website/src/Config.pudu` reads, which is passed through.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

compiler="${PUDU:-pudu}"
if ! command -v "$compiler" >/dev/null 2>&1; then
  echo "no compiler at '$compiler'; put pudu on PATH or set PUDU" >&2
  exit 1
fi

export PUDU_SITE_PORT="${PUDU_SITE_PORT:-8080}"
export PUDU_SITE_URL="${PUDU_SITE_URL:-http://localhost:$PUDU_SITE_PORT}"
# The playground runs programs with this same compiler, unconfined by
# namespaces, which a developer's own machine usually cannot create.
export PUDU_PLAYGROUND_RUNNER="${PUDU_PLAYGROUND_RUNNER:-local}"
export PUDU_PLAYGROUND_ISOLATION="${PUDU_PLAYGROUND_ISOLATION:-none}"
export PUDU_PLAYGROUND_COMPILER="${PUDU_PLAYGROUND_COMPILER:-$(command -v "$compiler")}"

# The Pudu sources under website/src are watched already; these are what the
# site reads besides them.
exec "$compiler" run --watch \
  --also website/docs \
  --also website/pages \
  --also website/data \
  --also website/public \
  --also website/playground/examples \
  --also website/dev \
  website/src/Main.pudu
