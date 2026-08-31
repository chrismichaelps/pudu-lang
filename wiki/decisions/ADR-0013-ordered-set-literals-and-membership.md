---
type: adr
status: accepted
date: 2026-08-31
tags: [adr, syntax, set, collections]
aliases: [ADR-0013 Ordered Set Literals and Membership]
---

# ADR-0013 — Ordered Set Literals and Membership

## Context

Pudu already has one ordered persistent `Set[T]`, constructed through `setOf` and queried through
`contains`. That representation is deterministic and rejects values without a language order, but
ordinary membership still exposes construction and method vocabulary at every use. Arrays and
records have literals; Set did not, despite being a wired-in collection with iteration and methods.

## Decision

Admit `#{a, b, c}` as a literal for the existing `Set[T]` and `value in set` as its membership
expression. This introduces no second Set type and no insertion-ordered variant.

- Literal members evaluate left to right. All written expressions run before duplicate values
  collapse in the ordered Set.
- Set identity, equality, iteration, and rendering remain key-ordered and independent of insertion
  order.
- `in` occupies the comparison band, associates left, evaluates its candidate before its Set, and
  returns `Bool`.
- The right operand must be `Set[T]`; the left must be `T`. This release does not introduce a
  membership trait or extend `in` to arrays, maps, strings, ranges, or user types.
- `#{}` is inferred from context. At a statement boundary where its element type remains unknown,
  `E3037` asks for a `Set[T]` annotation instead of choosing a default.
- A member without an admitted order retains runtime `E7008`, matching `setOf`.
- `for pattern in expression` retains its existing grammar: its `in` is a loop-head separator, not
  a binary expression.

## Examples

Before:

```pudu
let allowed = setOf([1, 2, 3])
if allowed.contains(candidate) { use(candidate) }
```

After:

```pudu
let allowed = #{1, 2, 3}
if candidate in allowed { use(candidate) }
```

An empty literal makes its element type visible:

```pudu
let none: Set[Int] = #{}
```

## Diagnostics and migration

The feature is backward-compatible. `#` was previously invalid source and `in` could not occur in
an expression, so no accepted program changes meaning. New `E3037` is reserved for an empty Set
literal whose element type remains unresolved at its statement boundary. Existing type mismatch
diagnostics cover a non-Set right operand or a candidate of the wrong type; `E7008` remains the
runtime defence for an unorderable member.

## Conformance

Parser, formatter, resolver, macro expansion, type checker, evaluator, REPL outline, LSP fixtures,
hostile-input budgets, and both ordinary and optimized test runs must agree. Native lowering is not
yet an independent execution path; when introduced, it must preserve the evaluator's source-order
member evaluation and key-ordered result.

## Grill Log

- **Q:** Should `in` dispatch through a general trait now? **A:** No. _Rationale:_ no such protocol
  exists, and inventing it inside a literal feature would leave maps, strings, ranges, borrowing,
  and complexity promises undecided. _Rejected:_ ad-hoc support for every built-in collection.
- **Q:** Should duplicate literals skip repeated expressions? **A:** No. _Rationale:_ evaluation is
  source ordered; uniqueness is a property of the resulting Set, not permission to remove work the
  program wrote. _Rejected:_ compile-time or run-time deduplication before evaluation.
- **Q:** Should an empty Set default to a particular element type? **A:** No. _Rationale:_ unlike an
  integer literal, no element exists to justify a default, and a silent choice would leak into API
  inference. _Rejected:_ `Set[()]`, `Set[Int]`, or a bottom-like element type.
- **Q:** Is this an insertion-ordered Set literal? **A:** No. _Rationale:_ Pudu already defines Set
  equality and traversal by key order. A literal must construct that value, not a second collection
  hidden behind the same type. _Rejected:_ retaining source order for rendering or iteration.

## Review date

2026-08-31. Revisit general membership only through a separate ADR with protocol, borrowing,
complexity, and ambiguity rules.

## Referenced by

[[decisions/_MOC]] · [[grammar/pudu]] · [[architecture/SEMANTICS]] · [[Eval Keyed]]
