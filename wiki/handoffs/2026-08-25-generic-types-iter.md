---
type: handoff
tags: [handoff, semantics, stdlib, iteration, numerics]
---

# Generic Types and Iteration Handoff

## Objective

Make generic user data types and implementations real enough to support an open sequence protocol,
then ensure the protocol preserves caller-selected integer types rather than falling back to `Int`.

## FMCF Roles

- **Language Architect:** resolved generic record instantiation, parameterised implementations,
  iteration element typing, the passed-state `Sequence` protocol, and the `Integer` boundary.
- **Semantic Engineer:** owns the existing issue #100 checker/evaluator/formatter changes and their
  mirrored pages; the current continuation is completing literal settlement and iterator adapters.
- **Standard Library Engineer:** owns `lib/Std/Num.pudu`, `lib/Std/Iter.pudu`,
  `test-fixtures/stdlib/UsesIter.pudu`, and their focused program checks for this continuation.
- **Forensic Guardian:** must audit source/wiki parity, public numeric claims, backlinks, changelog,
  private-input isolation, and validation evidence before readiness.

## Resolved Contract

- `Sequence[S, T]` passes state and never hides a mutable cursor.
- `Range[N]` requires `Integer + Ord + Add + One`; numeric traits alone are insufficient because
  floating values also implement them.
- `Integer` converts exactly to `BigInt` and fallibly back, preserving width and signedness without
  an internal conversion to `Int`.
- Iterator `Int` values are limited to positions and counts.
- Lazy adapters traverse only when advanced; `count` and `sum` do not materialise; `isEmpty` asks
  for at most one item; empty `sum` is `None`, never a panic.

## Deferred Numeric Migration

`Std.Random.below`/`between`/`numbers` and `Std.Text.Parse.integer` still fix caller data to `Int`.
They must move to the `Integer` contract in a focused follow-up after #100, with unbiased random
rejection sampling and parser-level range failures. Counts, positions, lengths, and percentages
remain `Int` under [[ADR-0006]].

## Exact Next Action

Implement the resolved `Integer` and streaming iterator contracts, add width/rejection/empty/lazy
regressions, run development and optimized gates, and obtain Language Architect plus Forensic
Guardian review before merging #100.

## Referenced by

[[handoffs/_MOC]] · [[Engineering Delivery]] · [[architecture/STDLIB]] · [[ADR-0006]]
