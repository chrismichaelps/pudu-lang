#!/usr/bin/env bash
# The site's Linux artefact, built to run where it is deployed.
#
# This used to build a Debian image and compile the compiler inside it, which
# produced a server linked against that image's glibc. It started nowhere older:
# the loader refuses before any Pudu code runs, so the failure named a library
# version rather than anything about the site, and every serverless deployment
# met it.
#
# Now the runtime is linked against musl once and the program is attached to it,
# which is the same step whatever platform the artefact is for. Nothing about
# the site is built differently for Linux.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
compiler="${PUDU:-pudu}"
runtime="${PUDU_MUSL_RUNTIME:-$root/dist/pudu-musl-x86_64}"

if [[ ! -f "$runtime" ]]; then
  echo "building the musl runtime first" >&2
  "$root/scripts/build-musl-runtime.sh" -o "$runtime"
fi

mkdir -p "$root/website/bin"

# The listener, for a platform that runs a daemon: Cloud Run, Fly.io, Render.
"$compiler" build "$root/website/src/Main.pudu" \
  -o "$root/website/bin/pudu-site-server-linux-x64" \
  --runtime "$runtime"

# The function, for a platform that invokes a program instead of connecting to
# it. Both serve `Web.Routes`, so there is one description of every page.
"$compiler" build "$root/website/src/Function.pudu" \
  -o "$root/website/bin/pudu-site-function-linux-x64" \
  --runtime "$runtime"

file "$root/website/bin/pudu-site-server-linux-x64"
file "$root/website/bin/pudu-site-function-linux-x64"
