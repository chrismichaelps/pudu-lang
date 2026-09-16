#!/usr/bin/env bash
# What the machine is actually asked to do, for one module of the compiler.
#
# A Pudu program has no machine code; the compiler that runs it does. This dumps
# that compiler's own intermediate forms for one module, at the optimisation the
# shipped build uses, so an optimisation can be judged against what was emitted
# rather than guessed at.
#
# The stages, in the order they are worth reading:
#
#   core  what the optimiser made of the source. Shows whether a function was
#         specialised, whether a dictionary is still being passed, whether a
#         value is boxed, and where a thunk is built. Most wins are visible here
#         and nowhere else, because they are about what survived the optimiser.
#   stg   the same after the last transformations, with allocation explicit.
#   cmm   the imperative form, before instruction selection.
#   asm   the instructions. Read this to confirm a loop is a loop rather than a
#         call through a dictionary, and to see the heap and stack checks.
#
# Usage:
#   bench/ir.sh Pudu.Eval.Match                 # every stage
#   bench/ir.sh Pudu.Eval.Match --stage core    # one stage
#   bench/ir.sh Pudu.Eval.Match --find sameValue

set -euo pipefail

module="${1:-}"
if [ -z "$module" ]; then
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi
shift

stage="all"
find_name=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stage) stage="${2:-all}"; shift 2 ;;
    --find) find_name="${2:-}"; shift 2 ;;
    *) echo "bench/ir.sh: unknown option $1" >&2; exit 2 ;;
  esac
done

source_path="src/$(echo "$module" | tr '.' '/').hs"
if [ ! -f "$source_path" ]; then
  echo "bench/ir.sh: no such module: $source_path" >&2
  exit 2
fi

relative="$(echo "$module" | tr '.' '/')"

# The dumps go in a build directory of their own.
#
# They are written only for modules the build actually compiles, and the
# ordinary build has already compiled everything: touching a source does not
# change that, because cabal decides by content hash, and deleting an object
# file does not either, because cabal trusts its own record over the file
# system. A separate directory has no record, so everything is compiled and
# everything is dumped. The first run is a full optimised build and takes
# minutes; later runs reuse it and are quick.
dumps="dist-ir"

# -O2 because that is what ships: Core read at -O0 describes a program nobody
# runs. The suppressions leave the names a reader is looking for and drop the
# annotations that bury them.
flags="-ddump-to-file -dsuppress-uniques -dsuppress-module-prefixes -dsuppress-idinfo"
case "$stage" in
  core) flags="$flags -ddump-simpl" ;;
  stg)  flags="$flags -ddump-stg-final" ;;
  cmm)  flags="$flags -ddump-cmm" ;;
  asm)  flags="$flags -ddump-asm" ;;
  all)  flags="$flags -ddump-simpl -ddump-stg-final -ddump-cmm -ddump-asm" ;;
  *) echo "bench/ir.sh: unknown stage $stage (core, stg, cmm, asm, all)" >&2; exit 2 ;;
esac

if [ ! -d "$dumps" ]; then
  echo "first run: building the library at -O2 into $dumps, which takes minutes ..."
else
  echo "building $module at -O2 with dumps ..."
fi
cabal build lib:pudu \
  --builddir="$dumps" \
  --enable-optimization=2 \
  --ghc-options="$flags" >/dev/null 2>&1 || {
  echo "bench/ir.sh: the build failed; run it without dumps to see why" >&2
  exit 1
}

found=0
for suffix in dump-simpl dump-stg-final dump-cmm dump-asm; do
  while IFS= read -r dump; do
    found=1
    size="$(wc -l < "$dump" | tr -d ' ')"
    echo
    echo "=== ${suffix#dump-}  ($size lines)"
    echo "    $dump"
    if [ -n "$find_name" ]; then
      # GHC writes a top-level name as `Module_name_info` in the instructions and
      # as a plain name in Core, so both spellings are worth looking for.
      matches="$(grep -n -- "$find_name" "$dump" | head -20 || true)"
      if [ -n "$matches" ]; then
        echo "$matches" | sed 's/^/    /'
      else
        echo "    (no mention of $find_name; it may have been inlined away)"
      fi
    fi
  done < <(find "$dumps" -path "*${relative}.$suffix" -type f ! -name "*.dyn.*" 2>/dev/null)
done

if [ "$found" -eq 0 ]; then
  echo "bench/ir.sh: no dumps were written for $module." >&2
  echo "GHC writes them only for modules it recompiled; try again." >&2
  exit 1
fi

echo
echo "A name that appears in none of these was inlined into its callers."
