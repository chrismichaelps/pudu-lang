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
language-server sessions, documentation parity, the generated-project workflow, and a real lint
command whose clean and failing exit statuses plus JSON output are checked outside the test runner.

## Governance and algorithm

Build products are removed before the warning gate so Cabal cannot answer from an older object. The
optimized executable path is resolved once and passed to behavioral scripts, including [[Generated
Project Gate]]. Independent checks continue after one fails; the script exits unsuccessfully when
any gate failed.

[[Live Lint Gate]] runs against that same optimized binary and proves failing findings, stable JSON,
safe fixing, compiler acceptance, and a clean second lint without modifying repository source.
[[Diagnostic Code Gate]] audits the intentional reuse of compiler warning identities by lint policy
and output instead of allowing a second, incompatible lint-only code vocabulary.

## Grill Log

- **Q:** Stop after the first gate? **A:** No. _Rationale:_ one release run should expose every
  independent repair needed. _Rejected:_ fail-fast orchestration.
- **Q:** Let scaffold behavior live only in a manual command? **A:** No. _Rationale:_ onboarding is
  a production surface and distribution lookup differs outside the checkout. _Accepted:_ the
  generated-project workflow is mandatory in this gate.

Resolved Grill Log: every release-relevant boundary runs against the same freshly optimized binary.

## Referenced by

[[architecture/DELIVERY]] · [[Diagnostic Code Gate]] · [[Generated Project Gate]] · [[Pudu CLI]]
