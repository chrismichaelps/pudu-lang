---
type: handoff
status: REVIEW
date: 2026-09-04
issue: 214
tags: [handoff, resolution, types, diagnostics]
aliases: [2026-09-04-type-as-value]
---

# Type Names Are Not Values Handoff

## Role transition

- **Language Architect:** preserves separate namespaces and the constructor-path exception.
- **Semantic Implementer:** owns `Semantic.Resolve`, `Resolve.Context`, the narrow prelude-type
  membership correction, integration fixtures, and their mirrors.
- **Independent Language Architect and Forensic Guardian:** review without editing; no unresolved
  P0/P1 finding may merge.

## Invariants

- A successful value-name resolution always identifies a binding evaluation can read.
- Bare and called type-only names report `E2010`; members a type does not declare report `E3034`.
- Value bindings win when one spelling exists in both namespaces.
- Record construction, bare variants, qualified variants, and imported values retain their current
  resolution and inferred types.
- An implicit dependency never makes an unimported module alias become valid by accident.

## Exact next action

Commit and push the complete issue #214 slice, open its PR to `dev`, obtain independent Language
Architect and Forensic Guardian approvals, and merge after fresh green GitHub checks.

## Validation plan

- Wired-in, implicit-prelude, and locally declared types are each refused bare and when called.
- The same three categories reject an invented member with the precise type-member diagnostic.
- Existing record-construction and qualified-variant tests pass unchanged.
- `pudu check` and `pudu run` no longer disagree for the reproductions in issue #214.

## Validation evidence

- The two integration fixtures report six `E2010` and three `E3034` diagnostics exactly.
- The resolver property preserves record construction, bare variants, and qualified variants.
- The complete no-optimization suite passes, including the real native and loopback integrations.
- `bash test/gates.sh` passes all seven optimized stages: warning-free build, full suite, Pudu
  formatting, diagnostic uniqueness, LSP session, LSP robustness, and documentation parity.
- Diagnostic uniqueness covers 128 codes across 129 sources with 18 intentional shared codes.

## Grill Log

- **Q:** Bind types as runtime values? **A:** No. _Rationale:_ Pudu has no first-class runtime type
  object, so evaluation has nothing to read. _Rejected:_ adding evaluator placeholders to mask the
  checker defect.
- **Q:** Remove all value-to-type fallback? **A:** No. _Rationale:_ record and qualified variant
  constructors intentionally begin with a type. _Rejected:_ breaking `Point { ... }` and
  `Shape.Circle` to repair ordinary expressions.
- **Q:** Diagnose in both resolution and typing? **A:** No. _Rationale:_ a phase that emits an error
  gates the later phase; each spelling receives one owner and one diagnostic. _Rejected:_ duplicate
  `E2010`/`E3034` cascades.

## Referenced by

[[handoffs/_MOC]] · [[Name Resolution]] · [[Resolve Context]] · [[Type Check Rule]]
