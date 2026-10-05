#!/usr/bin/env bash
# A derived implementation against the one a person would write by hand.
#
# Usage: bench/derive.sh "$(cabal list-bin exe:pudu --enable-optimization=2)"
#
# Both programs encode the same orders and print the total encoded length, so
# the comparison also proves they wrote the same text. Each runs five times per
# evaluator and the fastest run is reported.

set -euo pipefail
binary="${1:?usage: bench/derive.sh <pudu binary>}"
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

derived="$(PUDU_EVAL=tree "$binary" run "$here/derive/DerivedJson.pudu")"
written="$(PUDU_EVAL=tree "$binary" run "$here/derive/HandwrittenJson.pudu")"
if [ "$derived" != "$written" ]; then
  echo "outputs differ: derived $derived, handwritten $written" >&2
  exit 1
fi

printf '%-12s %8s %9s\n' encoder tree compiled
for name in DerivedJson HandwrittenJson; do
  file="$here/derive/$name.pudu"
  printf '%-12s %8s %9s\n' "${name%Json}" "$(fastest tree "$file")" "$(fastest compiled "$file")"
done
