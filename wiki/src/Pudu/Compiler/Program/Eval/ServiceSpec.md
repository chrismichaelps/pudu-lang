---
type: module
path: "@root/test/Pudu/Compiler/Program/Eval/ServiceSpec.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, service, evaluation]
aliases: [Service Evaluation Spec]
---

# Service Evaluation Spec

## Purpose and interface

Runs the Pudu fixtures for database, application lifecycle, HTML, UI, validation, authentication,
observability, scheduling, localization, and caching. Every fixture returns an exact assertion count;
the Haskell property attaches a contract-specific counterexample to that count.

## Governance and algorithm

The UI fixture counts cover pure component state, structural differences, the Pudu-native canvas'
exact pixels, repaint equality, and typed refusals, and declarative layout's exact frames,
accessibility semantics, and damage that repaints to the same bytes as a full render, and interactive
screens whose incremental frames after routed input equal a fresh start at the same state, bitmap
text whose measures, wrapping, and glyph pixels are exact, PCM audio whose samples, time, and WAV
bytes are exact, audio graphs whose split renders equal whole ones, and video timing and tracks that are
exact over long streams. Exact equality is intentional: adding a check without registering it
or skipping a branch changes the count and fails the host suite.

The desktop fixture keeps the standard suite display-independent by checking unsafe caption,
extent, pixel-budget, and pump-duration paths before a platform effect is reached. The separate
[[Launch Ui Desktop]] fixture is the macOS acceptance gate and must open an actual window; its
success is not inferred from this pure count.

## Grill Log

- **Q:** Accept a count greater than a minimum? **A:** No. _Rationale:_ a skipped refusal could be
  hidden by an unrelated added success. _Rejected:_ lower-bound fixture assertions.
- **Q:** Put UI patch validation only in Haskell? **A:** No. _Rationale:_ the public API is written
  in Pudu and must be exercised as its callers exercise it. _Rejected:_ duplicating its semantics in
  the host test language.

Resolved Grill Log: exact counts keep every Pudu-level assertion observable while named Haskell
counterexamples identify the failed service contract.

## Referenced by

[[Std Ui]] · [[Std Ui Canvas]] · [[Std Ui Layout]] · [[Std Ui Screen]] ·
[[Std Ui Desktop]] · [[2026-09-12-release-readiness-ui]]
