---
type: decision
status: Accepted
date: 2026-08-28
review_date: 2026-11-28
tags: [decision, syntax, patterns, control-flow]
aliases: [ADR-0010, Refutable Pattern Conditions]
---

# ADR-0010 — Refutable pattern conditions

**Status: Accepted.**

## Context

`match` is the complete branching form, but using it for one success pattern and one shared
fallback makes dependent `Option` and `Result` code drift rightward. Library composition such as
`Option.andThen` can collapse dependent absence, yet the caller still needs to bind the successful
payload and choose one fallback. Boolean conditions cannot bind a value whose scope begins only
after a pattern succeeds.

## Decision

Admit one focused surface form:

```pudu
if let Some(value) = candidate {
  use(value)
} else {
  fallback()
}
```

The subject evaluates exactly once. On success, immutable pattern bindings exist only in the then
block. On failure, the optional else expression runs; without one the result is `()`. Branch types
unify exactly as ordinary `if` branches do. `else if let` is ordinary right-nesting.

The surface tree preserves `IfLetExpression` so formatter, REPL outline, diagnostics, and source
tools describe what the reader wrote. Resolution, typing, and evaluation reuse the same pattern
binding/matching primitives as `match`; no second pattern semantics is introduced.

A syntactically irrefutable pattern is `E1056` at the pattern. A writer uses ordinary `let` for an
unconditional binding. Pattern conditions are not admitted inside arbitrary `&&` or `||` chains;
their short-circuit binding scope would introduce a second, harder scope grammar.

## Compatibility and migration

Before this addition, one successful pattern and one fallback required the complete form:

```pudu
match candidate { case Some(value) => use(value) case None => fallback() }
```

That source remains valid and keeps identical meaning. Authors may migrate it mechanically to the
`if let` form above only when every non-success pattern shares the same fallback; a `match` whose
arms make different decisions stays a `match`. The change is backward-compatible and claims one
parser diagnostic, `E1056`; existing diagnostic meanings and codes do not move.

The interpreter is the executable conformance oracle for single evaluation, binding scope, branch
typing, and unit fallback. The planned native backend must run the same conformance fixtures before
it may claim this syntax; until that backend exists, no interpreter/native equivalence is claimed.
This decision is reviewed on 2026-11-28, or earlier if lowering introduces a semantic mismatch.

## Consequences

- Dependent sum-type code becomes one-dimensional without weakening exhaustive `match`.
- Tooling retains the surface construct rather than showing an invented match arm.
- Every semantic phase gains one shallow dispatch case but delegates the actual pattern rule.
- `while let` and `let … else` remain separate possible features with independent motivation.

## Rejected alternatives

- Parser-only lowering to `MatchExpression`: smallest compiler diff, but loses surface identity and
  can expose synthetic-arm diagnostics.
- Arbitrary `let` clauses inside boolean expressions: compact, but creates order-dependent binding
  scopes inside precedence parsing.
- A new propagation operator for `Option`: does not fit local fallback code and duplicates `?`'s
  result-propagation role.
- More `match` punctuation or symbolic bind operators: reduces characters without reducing the
  semantic decisions a reader must track.

## Referenced by

[[decisions/_MOC]] · [[grammar/pudu]] · [[architecture/SEMANTICS]] · [[Parser Expression Control]] · [[Syntax Tree]]
