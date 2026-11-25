#!/usr/bin/env bash
# Runs the property suite on every core. Each property is its own job; jobs
# start longest first, from the seconds the previous run recorded, so one
# slow property never waits behind a queue of quick ones. Every compile goes
# through test/cc-cache, so an unchanged program reuses its binary.
#
#   test/parallel.sh                 every property
#   PUDU_TEST_MATCH=native test/parallel.sh   properties whose label contains "native"
#   PUDU_TEST_JOBS=4 test/parallel.sh         four workers
#   PUDU_TEST_DEBUG=1 test/parallel.sh        the unoptimized suite in dist-fast: a quicker
#                                             build, a much slower run of the large programs
set -u

if [ "${1:-}" = "--one" ]; then
  # Worker: one property, its log, and its status.
  label=$2 log=$3
  PUDU_TEST_LABEL="$label" "$PUDU_TEST_BINARY" > "$log" 2>&1
  echo "$?" > "$log.status"
  exit 0
fi

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
jobs=${PUDU_TEST_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)}
# The suite compiles large programs in-process, so an optimized build runs it
# several times faster; its own build costs a few minutes once.
if [ -n "${PUDU_TEST_DEBUG:-}" ]; then
  builddir=${PUDU_TEST_BUILDDIR:-dist-fast}
  build_flags=()
else
  builddir=${PUDU_TEST_BUILDDIR:-dist-test-opt}
  build_flags=(--enable-optimization=1)
fi
state="${XDG_CACHE_HOME:-$HOME/.cache}/pudu-test"
durations="$state/durations"
logs=$(mktemp -d "${TMPDIR:-/tmp}/pudu-parallel.XXXXXX")
mkdir -p "$state"
touch "$durations"
started=$(date +%s)

echo "building the suite ($builddir)"
if ! cabal build all --builddir="$builddir" ${build_flags[@]+"${build_flags[@]}"} --ghc-options=-Werror > "$logs/build.log" 2>&1; then
  grep -E -A8 " error" "$logs/build.log" | head -40
  echo "build failed; full log: $logs/build.log"
  exit 1
fi

PUDU_TEST_BINARY=$(cabal list-bin pudu-tests:test:pudu-test --builddir="$builddir" ${build_flags[@]+"${build_flags[@]}"})
export PUDU_TEST_BINARY
export PATH="$root/test/cc-cache:$PATH"
export PUDU_LIB="${PUDU_LIB:-$root/packages/pudu/v0.1/lib}"
unset PUDU_TEST_SHARD

# Every label, narrowed by PUDU_TEST_MATCH, ordered longest first; a label
# with no recorded time starts first.
PUDU_TEST_LIST=1 "$PUDU_TEST_BINARY" > "$logs/labels" 2>/dev/null
if [ -n "${PUDU_TEST_MATCH:-}" ]; then
  grep -F -- "$PUDU_TEST_MATCH" "$logs/labels" > "$logs/selected" || true
else
  cp "$logs/labels" "$logs/selected"
fi
unset PUDU_TEST_MATCH
total=$(wc -l < "$logs/selected" | tr -d ' ')
awk -F'\t' 'FILENAME == ARGV[1] { seconds[$2] = $1; next } { print (($0 in seconds) ? seconds[$0] : 1000000) "\t" FNR "\t" $0 }' \
  "$durations" "$logs/selected" | sort -t "$(printf '\t')" -k1,1nr | cut -f2- > "$logs/queue"

echo "running $total properties on $jobs workers; logs in $logs"
cut -f1,2 "$logs/queue" | while IFS="$(printf '\t')" read -r index label; do
  printf '%s\0%s\0' "$label" "$logs/$index.log"
done | xargs -0 -n 2 -P "$jobs" "$0" --one

failed=0
for status in "$logs"/*.log.status; do
  [ -e "$status" ] || continue
  log=${status%.status}
  if [ "$(cat "$status")" != 0 ] || grep -q -E "Falsified|Gave up|\*\*\* Failed" "$log"; then
    failed=$((failed + 1))
    echo "FAILED $(grep -m1 '^\[test\]' "$log" | cut -c8-)"
    grep -A3 -E "Falsified|Gave up|\*\*\* Failed" "$log" | head -6 | cut -c1-400
  fi
done

# Keep the newest seconds of each property for the next ordering.
cat "$logs"/*.log 2>/dev/null | awk '/^\[done\] / { seconds = $2; $1 = ""; $2 = ""; sub(/^  /, ""); print seconds "\t" $0 }' > "$logs/timed"
# Labels the suite no longer has are dropped.
awk -F'\t' 'FILENAME == ARGV[1] { fresh[$2] = $1; next } FILENAME == ARGV[2] { known[$0] = 1; next }
  !($2 in fresh) && ($2 in known) { print } END { for (label in fresh) print fresh[label] "\t" label }' \
  "$logs/timed" "$logs/labels" "$durations" > "$durations.next" && mv "$durations.next" "$durations"

elapsed=$(( $(date +%s) - started ))
passed=$(cat "$logs"/*.log 2>/dev/null | grep -c "OK, passed")
echo "properties=$total passed=$passed failed=$failed elapsed=${elapsed}s"
[ "$failed" = 0 ]
