---
type: handoff
tags: [handoff, language, frontend, semantics, tooling]
---

# `if let` Pattern Condition Handoff

## Objective

Flatten a one-success/one-fallback pattern branch while preserving exhaustive `match` as Pudu's
general branching form. `Std.Http.formDecode` is the natural regression: compose its dependent
`Option` steps, then bind the successful character through one `if let`.

## FMCF Roles

- **Language Architect:** owns [[ADR-0010 Refutable Pattern Conditions]], grammar, scope, evaluation
  order, result typing, and the `E1056` irrefutability boundary.
- **Frontend/Semantic Engineer:** owns the surface node, parser, resolver, checker, evaluator,
  outline, and focused tests named by issue #129.
- **Forensic Guardian:** independently reviews behavior, diagnostics, source/wiki parity, line
  limits, validation evidence, and private-input boundaries before PR readiness.

## Resolved Contract

- `if let PATTERN = EXPRESSION BLOCK (else (if-expression | BLOCK))?` evaluates the expression once.
- Successful immutable bindings exist only in the then block. Failure evaluates else, or yields
  unit when else is absent.
- The surface tree remains `IfLetExpression`; each semantic phase reuses its existing pattern
  primitive rather than lowering in the parser or inventing new matching rules.
- `else if let` is a flat source spelling and a nested conditional tree.
- Wildcard, binding, and structurally irrefutable tuple/record/alternative patterns are `E1056`.
- `while let`, `let … else`, and pattern clauses inside boolean chains are not part of issue #129.

## Validation Contract

Cover success, failure, absent else, `else if let`, single subject evaluation, branch-local scope,
pattern type mismatch, `E1056` code/span/help, malformed syntax recovery, formatter and outline,
the `formDecode` fixture, recursion budget, full O0/O2, warning-clean build, corpus, diagnostics,
LSP, and documentation parity.

## Exact Next Action

Implement only the pages and files mirrored by this handoff, then obtain independent semantic and
Forensic Guardian review before committing and opening the issue #129 PR to `dev`.

## Referenced by

[[handoffs/_MOC]] · [[ADR-0010 Refutable Pattern Conditions]] · [[grammar/pudu]] · [[Parser Expression Control]]
