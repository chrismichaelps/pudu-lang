---
type: handoff
status: IN_REVIEW
issue: 545
aliases: [Qualified Import Delivery]
tags: [imports, resolution]
---
# Qualified Import Delivery

Semantic Engineer owns Type.Env, Type.Check.Install and their mirrors; Test Engineer owns Qualified Import Spec and its runner/manifest registrations. Transitions: Semantic Engineer → Test Engineer → Forensic Guardian. Work is direct and sequential on fresh feature/545-qualified-import-shadow from development. Complete mirrors with resolved Grill Logs preceded the source edits. No syntax changes.

Baseline: under `import Lib.Pages as Pages`, a module exporting `show(Str, Int)` made the importer's `show(3)` an arity and type error (E3003, E3001). Name resolution was correct — an unselected export reached bare was already E2010 — but the checker declared each imported function under its bare name in the shared module frame, published it under its qualifier, and left the bare binding behind. Only a name the resolver accepts for another reason, such as a prelude value, could reach it. The evaluator already bound imports qualified only.

Repair: `preservingName` scopes the bare declaration and restores the previous scheme, unsafe capabilities and compile-time standing. Selected imports keep binding bare names through the consumer's import table.

Evidence: both Qualified Import Spec families pass; with the install change reverted, the loaded family fails on the issue's program with E3003 and E3001. All 614 complete-suite groups pass at -O0; the strict `-O2 -Werror` build of every component is clean (it first caught a defaulted literal type in the new spec, now annotated), and the qualified families pass in the optimized test binary. No darwin-only module was touched. Independent semantic and vault-parity reviews remain pending.

Exact next action: Forensic Guardian reviews the pull request against these mirrors; on approval, merge to development.

## Referenced by

[[handoffs/_MOC]] · [[Qualified Import Spec]] · [[Type Check Install]]
