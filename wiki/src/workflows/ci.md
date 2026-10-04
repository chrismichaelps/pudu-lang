---
type: module
path: "@root/.github/workflows/ci.yml"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
tags: [module, workflow, ci, performance]
aliases: [Compiler CI Workflow]
---

# Compiler CI Workflow

## Purpose and interface

Validate pull requests to dev/main and pushes to dev/main on Ubuntu with the
locked GHC 9.14.1, Cabal 3.16.1.0 and Node 22. Contents permissions stay read-only.
One compiler job runs all existing release, language, package, website, runtime,
LSP, documentation and performance-smoke gates.

## Build/cache algorithm

Install libffi headers, restore the Cabal dependency store from the setup action's
`cabal-store` output, refresh the package index and build all local packages once
with optimization=2 and -Werror. Cache identity includes runner OS/architecture,
actual GHC/Cabal versions, optimization/warning configuration and dependency
manifests. Compatible prefixes reuse immutable dependency units when source
module registration changes. A cache miss performs a normal dependency build.

Do not restore dist-newstyle, local source objects, executable products, Pudu
products or test results. The warning gate always builds this checkout. The full
suite uses the same -O2/-Werror flags. Resolve PUDU once with optimization=2;
formatter, Std/examples checker and all documentation commands invoke that exact
executable. Cabal remains responsible for the build and Haskell test suite.

## Behavioral gates

Preserve scheduled API removals, full-suite timeout, committed-source formatting,
Std/example acceptance, runnable documentation/playground examples, website
checking/formatting/test suites, topic discovery, syntax parity, package registry
and terminal installation, sandbox refusal, Linguist consistency, diagnostic
identity, release planning, real LSP sessions/robustness, watch restarts, signal
draining, bundles/runtime packs, third-party foreign calls, socket service,
scaffolding, API coverage, streaming residency and documentation site output plus
its missing-input/missing-file refusal cases.

## Negative logic and edge cases

No skip based on a cache hit, no unoptimized fallback, no second local build with
weaker flags, no change to dependency versions or language semantics. Failed
cache restoration does not establish validation. Source changes must still
compile; a dependency manifest change must still resolve compatible units.
Haskell cold bootstrap time, test duration and Pudu check latency remain distinct
measurements. Hosted cache savings require an actual hosted run to quantify.

## Grill Log

- **Q:** Cache all build products to eliminate the warning gate? **A:** No; cache
  immutable dependency units only. _Rationale:_ local source objects must be
  validated in the current checkout. _Rejected:_ restored dist-newstyle and
  skipping build/test on a hit.
- **Q:** Re-enter Cabal for each CLI gate? **A:** Use the already resolved PUDU.
  _Rationale:_ the project defaults to no optimization and those commands select
  a different configuration. _Rejected:_ repeated cabal run without build flags.
- **Q:** Drop -Werror for tests after building? **A:** Keep one configuration.
  _Rationale:_ test invocation must not replace the verified configuration.
  _Rejected:_ redundant relaxed build or a separate unoptimized gate executable.

## Referenced by

[[src/_MOC]] · [[Repository Gates]] · [[Engineering Delivery]] ·
[[handoffs/2026-10-04-ci-latency]]
