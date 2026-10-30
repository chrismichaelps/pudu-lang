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


printf 'gates\n'
run 'native desktop frames preserve row orientation' node test/desktop-presentation.mjs
run 'refresh installs an optimized compiler and verifies PATH' python3 test/refresh-install.py
run 'application dependency model refuses architectural defects' node --test test/app-layers.test.mjs
run 'application imports follow their declared dependency layers' node scripts/app-layers.mjs
run 'Ark dependency model refuses architectural defects' node --test test/ark-layers.test.mjs
run 'Ark imports follow their declared dependency layers' node scripts/ark-layers.mjs
while IFS= read -r project_build_root; do
  rm -rf "${project_build_root}/opt" "${project_build_root}/noopt" \
    "${project_build_root}/x" "${project_build_root}/t"
done < <(find dist-newstyle/build -mindepth 3 -maxdepth 3 -type d \
  \( -name 'pudu-[0-9]*' -o -name 'pudu-tests-[0-9]*' \) 2>/dev/null)
run 'no warnings, optimized' \
  cabal build all --enable-optimization=2 --ghc-options='-Werror'
run 'full suite, optimized' \
  cabal test all --enable-optimization=2 --ghc-options='-Werror' --test-show-details=direct

# `cabal list-bin` answers for the configuration it is asked about, not the one
# that was built. Asked plainly it names the unoptimized path: right after the
# build products are removed above that file does not exist, and on a tree that
# has also been built unoptimized it names a binary from some earlier day, so
# the gates below pass while testing something nobody just compiled. Resolved
# once, with the flag the build used, and exported so the gates that run in a
# child shell see the same answer.
export PUDU
PUDU=$(cabal list-bin pudu --enable-optimization=2)
run 'generic methods preserve checked trait providers' node test/bound-provider.mjs "$PUDU"
# The directories are given to the formatter rather than expanded here: a
# shell expansion that matches nothing passes this gate while checking nothing.
run 'every committed Pudu file is formatted' \
  bash -c '"$PUDU" fmt --check packages/pudu test-fixtures examples'
run 'capsules cast against finite boxes with checked witnesses and convergence' \
  node test/ark-cast.mjs "$PUDU"
run 'Ark capsules sweep, slide and classify support' \
  node test/ark-character.mjs "$PUDU"
run 'qualified constructors preserve types, visibility and runtime values' \
  node test/qualified-variants.mjs "$PUDU"
run 'explicit traits preserve their provider result schemes' \
  node test/trait-provider.mjs "$PUDU"
run 'every diagnostic code means one thing' node test/diagnostic-codes.mjs
run 'desktop configure refuses each invalid setting by name' \
  bash -c 'node test/desktop-configure.mjs "$PUDU"'
run 'capsule support preserves floor policy, state and typed errors' \
  node test/ark-ground.mjs "$PUDU"
run 'swept movement preserves contacts, errors and unapplied travel' \
  node test/ark-motion.mjs "$PUDU"
run 'Ark math preserves scaled geometry and refuses wrong precision' \
  node test/ark-math.mjs "$PUDU"
run 'Ark matrices preserve composition and checked homogeneous projection' \
  node test/ark-matrix.mjs "$PUDU"
run 'Ark assets preserve linear-light sampling and checked texture storage' \
  node test/ark-assets.mjs "$PUDU"
run 'Ark physics preserves numeric admission and disjoint contact batches' \
  node test/ark-physics.mjs "$PUDU"
run 'Ark animation samples, blends and cross-fades joint poses' \
  node test/ark-animation.mjs "$PUDU"
run 'Ark audio mixes buses, spatial voices and PCM16 blocks' \
  node test/ark-audio.mjs "$PUDU"
run 'Ark game loop runs fixed steps, scene stacks and camera rigs' \
  node test/ark-game.mjs "$PUDU"
run 'Ark UI handles pointer and keyboard focus and draws its widgets' \
  node test/ark-ui.mjs "$PUDU"
run 'Ark net acknowledges packets and replicates quantized deltas' \
  node test/ark-net.mjs "$PUDU"
run 'Ark build cooks checked packs and loads them through the asset server' \
  node test/ark-build.mjs "$PUDU"
run 'atomic writes preserve creation and replacement permissions' \
  bash -c 'python3 test/atomic-permissions.py "$PUDU"'
run 'only a compiler change at a new version releases' python3 test/release-plan.test.py
run 'the fixtures still reach as much of the library' \
  bash -c 'node test/api-coverage.mjs "$PUDU"'
run 'a streaming reader holds as much at ten times the input' \
  bash -c 'python3 test/residency.py "$PUDU"'
run 'bounded concurrency helpers release what they create' \
  bash -c 'node test/concurrent-release.mjs "$PUDU"'
run 'lane kernel buffers share collections across calls' \
  bash -c 'node test/lane-collections.mjs "$PUDU"'
run 'pudu installs and publishes packages through git and a stand-in GitHub' \
  bash -c 'python3 test/package-registry.py --pudu "$PUDU"'
run 'pudu install adds, moves, restores, and removes packages as a terminal uses it' \
  bash -c 'python3 test/package-install.py --pudu "$PUDU"'
run 'a generated project works outside the repository' \
  bash -c 'node test/scaffold.mjs "$PUDU"'
run 'typed lint findings and safe fixes work through the real CLI' \
  bash -c 'node test/lint.mjs "$PUDU"'
run 'the language server answers a real session' \
  bash -c 'node test/lsp-session.mjs "$PUDU"'
run 'the language server survives what an editor sends it' \
  bash -c 'node test/lsp-robustness.mjs "$PUDU"'
run 'a watched program starts again for its sources and its --also paths' \
  bash -c 'node test/watch.mjs "$PUDU"'
run 'the documentation site keeps its contract' \
  bash -c '"$PUDU" doc --html test-fixtures/stdlib/UsesAll.pudu | node test/doc-site-parity.mjs'

run 'derive documentation and public API boundaries' \
  bash -c 'node test/derive-index.mjs "$PUDU"'

if [ "$failed" -ne 0 ]; then
  printf '\nat least one gate failed\n'
  exit 1
fi
printf '\nevery gate passed\n'
