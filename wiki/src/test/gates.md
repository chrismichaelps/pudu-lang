---
type: module
path: "@root/test/gates.sh"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, release, gates]
aliases: [Repository Gates]
---

# Repository Gates

## Purpose and interface

Run the production release checks in a fixed order and report every failing gate: warning-free
optimized build, optimized full suite, Pudu formatting, diagnostic identities, API coverage, live
language-server sessions, documentation parity, and the generated-project workflow.

## Governance and algorithm

Build products are removed before the warning gate so Cabal cannot answer from an older object. The
optimized executable path is resolved once and passed to behavioral scripts, including [[Generated
Project Gate]]. Independent checks continue after one fails; the script exits unsuccessfully when
any gate failed.

## Grill Log

- **Q:** Stop after the first gate? **A:** No. _Rationale:_ one release run should expose every
  independent repair needed. _Rejected:_ fail-fast orchestration.
- **Q:** Let scaffold behavior live only in a manual command? **A:** No. _Rationale:_ onboarding is
  a production surface and distribution lookup differs outside the checkout. _Accepted:_ the
  generated-project workflow is mandatory in this gate.

Resolved Grill Log: every release-relevant boundary runs against the same freshly optimized binary.

## Referenced by

[[architecture/DELIVERY]] · [[Generated Project Gate]] · [[Pudu CLI]]
