---
type: handoff
status: ACTIVE
tags: [handoff, regression, checker, runtime, stdlib]
---

# Production Bug Repairs

## Objective and delivery

Repair issues #371, #372, #373, #376, #377, #378, #379, #381, #382, #383, and #384.
The user explicitly requests one commit per completed issue directly on `dev`, with Pudu
formatting before each commit and no PR. That instruction overrides the ordinary branch/PR
workflow for this batch. Private governance inputs remain ignored and excluded.

## Role transitions and ownership

Language Architect → Runtime Engineer: Decimal dispatch and nested equality, evaluator modules
and focused runtime tests. Language Architect → Semantic Engineer: alias formation and module
isolation, imported constants, match coverage, and Option method diagnostics, with disjoint
formation, folding, exhaustiveness, and method-test ownership. Language Architect → Standard
Library Engineer: YAML compact sequences, quoted scalars, and block scalars in issue order.
Each implementation returns to independent Language Architect and Forensic Guardian review
before the Tooling/Release Engineer formats, validates, and commits its exact owned files.
Shared test harness and MOC/changelog integration belong to the delivery owner.

## Acceptance and risks

Preserve canonical module identities, transparent aliases, compile-time effect denial, closed
match completeness, numerical Decimal equality at every nesting level, and typed YAML refusal.
Add success/failure/regression/output evidence, preserve formatter stability, and run the full
suite and warning gates. Independent reviewers cannot author the implementation they approve.

## State

#381: independent Language Architect and Forensic Guardian review approved after correcting
the depth guard; exact tree/depth/tab regressions and formatter checks pass. #371: Decimal dispatch passed focused tests and independent review; its fixture is formatted.
#377: correlated tuple tests pass after executable test registration; independent review approved.
#372: imported late/chained aliases passed focused compile/run/refusal tests and independent review.
#383: exact unwrapOr regressions pass on the fresh binary; independent review approved.
#382: quoted YAML fixture, formatter, API coverage and independent review pass.
Remaining issues are in progress.

## Exact next action

Implement #384 block scalar retention after the #382 commit.

## Referenced by

[[handoffs/_MOC]] · [[CHANGELOG]]
