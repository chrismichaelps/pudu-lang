---
type: module
path: "@root/lib/Std/Order.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, order, hash]
aliases: [Std Order]
---
# Std Order
## Purpose
Name equality, ordering, and hashing contracts used by generic algorithms and keyed collections.
## Interface
Exports `Ordering`, scalar comparisons, ordering combinators, `Eq`, `Ord`, `Hash`, their generic
helpers, and implementations for compiler-wired scalar/byte types.
## Governance and algorithm
`Eq` defines semantic identity, `Ord` defines relative placement, and `Hash` only selects candidate
buckets. Equal values must hash equally; collisions remain distinct until `Eq` compares them.
`Ord.before` asks whether the left value belongs strictly before the right value. Equal values and
values ordered after the right value both answer `false`. Primitive implementations inherit this
contract text in generated documentation unless a concrete implementation supplies its own note.
## Grill Log
- **Q:** Put `Hash` inside `Std.HashMap`? **A:** No. _Rationale:_ the law belongs to the key type and
  is reusable by every hashed collection. _Rejected:_ treating SHA-256 as the trait operation.
- **Q:** Repeat `Ord.before` documentation on every primitive implementation? **A:** No.
  _Rationale:_ the strict-order contract belongs to the trait member and generated documentation
  can inherit it precisely through the named trait. _Rejected:_ copied comments that can drift.

Resolved Grill Log: `Ord.before` owns the strict-order explanation; implementation-specific text
remains an explicit override.
## Referenced by
[[src/Std/_MOC]] · [[Std HashMap]] · [[ADR-0015-hash-contract-and-hash-map]]
