#!/usr/bin/env bash
# Measure startup, checking and runtime with one monotonic harness.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
exec node "$here/eval.mjs" "$@"
