#!/usr/bin/env bash
# What one evaluated step costs, in each evaluator.
#
# Usage: bench/eval.sh "$(cabal list-bin exe:pudu --enable-optimization=2)"
#
# Each benchmark is run five times per evaluator and the fastest run is
# reported, because a busy machine adds time and never takes it away. The tree
# walker is the reference; `compiled` is what `pudu run` uses by default.

set -euo pipefail
binary="${1:?usage: bench/eval.sh <pudu binary>}"
here="$(cd "$(dirname "$0")" && pwd)"
export PUDU_LIB="${PUDU_LIB:-$here/../packages/pudu/v0.1/lib}"

fastest() {
  local mode="$1" file="$2" best=""
  for _ in 1 2 3 4 5; do
    local start end elapsed
    start=$(python3 -c 'import time; print(time.time())')
    PUDU_EVAL="$mode" "$binary" run "$file" >/dev/null
    end=$(python3 -c 'import time; print(time.time())')
    elapsed=$(python3 -c "print(round($end - $start, 2))")
    if [ -z "$best" ] || python3 -c "import sys; sys.exit(0 if $elapsed < $best else 1)"; then best="$elapsed"; fi
  done
  echo "$best"
}

printf '%-10s %8s %9s\n' benchmark tree compiled
for file in "$here"/eval/*.pudu; do
  name="$(basename "$file" .pudu)"
  printf '%-10s %8s %9s\n' "$name" "$(fastest tree "$file")" "$(fastest compiled "$file")"
done
