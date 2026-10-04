---
type: handoff
tags: [handoff, ci, performance]
---

# Compiler CI latency

Issue #436 starts from freshly fetched dev (71fb2adf) on
`feature/436-ci-latency`, isolated from compiler #435 and active Derive work.
Architect → Tooling/Release Engineer owns .github/workflows/ci.yml, test/gates.sh,
their complete mirrors, MOCs and changelog. Work is solo. No PR/dev promotion yet.

A successful dev baseline run, 36873078059, spends 713 seconds in the build,
7 seconds in a second configuration, 168 seconds in the suite, 66 seconds in the
formatter and 80 seconds checking Std/examples. The last commands call Cabal
without optimization although the optimized PUDU is already available.

Resolved Grill Log: cache only the Cabal store, retain fresh checkout compilation,
keep -O2/-Werror for build and tests, and call the selected binary for behavioral
gates. The cache action's v6.1.0 documentation and setup v2's cabal-store/version
outputs are verified against their official repositories. No dependency version
or semantic contract changes.

## Exact next action

After authorized integration, compare the supported runner's build and CLI gate
durations with successful baseline run 36873078059. A hosted cache hit and actual
CI duration remain unmeasured until this workflow runs on that runner.

## Referenced by

[[handoffs/_MOC]] · [[Compiler CI Workflow]] · [[Repository Gates]]

Validation: Ruby YAML parsing, bash syntax, single strict build/test configuration,
selected executable, store-only cache scope and absence of skipped gates pass.
The optimized matching-dev compiler passes repository formatting, every Std and
example check, documentation site parity (155 entries), and both missing-input
and missing-file refusal statuses. Compiler #435's full 464-family suite passes
on the same dev source lineage; no hosted GHC 9.14.1 execution is claimed.
