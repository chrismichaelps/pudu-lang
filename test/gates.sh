#!/usr/bin/env bash
# Run what CI runs, in the order CI runs it, and say which gate failed.
#
# A fresh checkout cannot be up to date, so CI's warning gate always compiles.
# Locally it frequently does not: cabal answers "Up to date" after a source
# changed, and a gate that did not compile reports a clean tree while checking
# none of it. That has hidden real errors here more than once.
#
# `--ghc-options=-fforce-recomp` does not fix it, and believing otherwise cost
# an hour: that flag is GHC's, and when cabal decides the package is up to date
# it never invokes GHC, so the flag is never seen. Only removing the build
# products makes the next build real. That is what this does, which is why it
# takes minutes rather than seconds — and why the answer is worth having.
set -u

BUILD_ROOT=$(find dist-newstyle/build -maxdepth 3 -type d -name 'pudu-*' 2>/dev/null | head -1)

failed=0

run() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '  ok    %s\n' "$name"
  else
    printf '  FAIL  %s\n' "$name"
    failed=1
  fi
}

pudu_bin() { cabal list-bin pudu; }

printf 'gates\n'
if [ -n "${BUILD_ROOT}" ]; then
  rm -rf "${BUILD_ROOT}/opt" "${BUILD_ROOT}/noopt" "${BUILD_ROOT}/x" "${BUILD_ROOT}/t"
fi
run 'no warnings, optimized' \
  cabal build all --enable-optimization=2 --ghc-options='-Werror'
run 'full suite, optimized' \
  cabal test all --enable-optimization=2 --test-show-details=direct
run 'every committed Pudu file is formatted' \
  bash -c 'cabal run -v0 pudu -- fmt --check $(find lib test-fixtures -name "*.pudu")'
run 'every diagnostic code means one thing' node test/diagnostic-codes.mjs
run 'the language server answers a real session' \
  bash -c 'node test/lsp-session.mjs "$(cabal list-bin pudu)"'
run 'the language server survives what an editor sends it' \
  bash -c 'node test/lsp-robustness.mjs "$(cabal list-bin pudu)"'
run 'the documentation site keeps its contract' \
  bash -c 'cabal run -v0 pudu -- doc --html test-fixtures/stdlib/UsesAll.pudu | node test/doc-site-parity.mjs'

if [ "$failed" -ne 0 ]; then
  printf '\nat least one gate failed\n'
  exit 1
fi
printf '\nevery gate passed\n'
