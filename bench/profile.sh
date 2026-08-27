#!/usr/bin/env bash
# Where the compiler's time goes, by cost centre.
#
# This is the question to ask before reading any intermediate form. A dump of
# the whole compiler is megabytes; a profile says which of its functions to look
# at, and `bench/ir.sh` then says why that one is slow. Asked in the other
# order, the dump is a haystack.
#
# Usage:
#   bench/profile.sh check some/file.pudu
#   bench/profile.sh run  some/file.pudu
#
# Writes pudu.prof beside the working directory and prints the heaviest entries.

set -euo pipefail

command="${1:-}"
target="${2:-}"
if [ -z "$command" ] || [ -z "$target" ]; then
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

# A profiling build is a separate build: every dependency needs its profiling
# way too, so it does not share objects with the ordinary one. The first run
# builds all of it and takes a while.
profiled="dist-prof"

echo "building a profiling executable into $profiled (the first run takes a while) ..."
cabal build exe:pudu \
  --builddir="$profiled" \
  --enable-profiling \
  --profiling-detail=toplevel-functions \
  --enable-optimization=2 >/dev/null 2>&1 || {
  echo "bench/profile.sh: the profiling build failed." >&2
  echo "Dependencies need their profiling way; 'cabal build --enable-profiling' shows why." >&2
  exit 1
}

# `list-bin` answers for the flags it is given, so it must be given the same
# ones the build had, or it names a path that was never built.
executable="$(cabal list-bin exe:pudu \
  --builddir="$profiled" \
  --enable-profiling \
  --profiling-detail=toplevel-functions \
  --enable-optimization=2 2>/dev/null || true)"
if [ ! -x "${executable:-}" ]; then
  executable="$(find "$profiled" -type f -name pudu -perm -u+x 2>/dev/null | head -1)"
fi
if [ -z "$executable" ] || [ ! -x "$executable" ]; then
  echo "bench/profile.sh: could not find the profiling executable." >&2
  exit 1
fi

echo "profiling: $command $target"
# -p writes the cost-centre report; the run's own exit status is the program's
# answer and is not a failure to profile.
"$executable" "$command" "$target" +RTS -p -RTS >/dev/null 2>&1 || true

if [ ! -f pudu.prof ]; then
  echo "bench/profile.sh: no pudu.prof was written." >&2
  exit 1
fi

echo
echo "heaviest cost centres (individual time, then allocation)"
echo
# The report's columns are: COST CENTRE, MODULE, SRC, no., entries, %time, %alloc
awk '
  NR <= 40 && /^[[:space:]]*COST CENTRE/ { header = 1 }
  header && NF >= 7 && $6 ~ /^[0-9.]+$/ && ($6 + 0) >= 1.0 {
    printf "  %-34s %-28s %6s%%time %6s%%alloc\n", $1, $2, $6, $7
  }
' pudu.prof | head -25

echo
echo "Full report: pudu.prof"
echo "Then: bench/ir.sh <the module named above> --find <the function named above>"
