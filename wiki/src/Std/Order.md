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
`Array[A]` and `Option[A]` implement Eq, Hash and Ord through their elements. `derive Eq`, `derive Hash` and `derive Ord` are ordinary derives for records and sums: equality field by field, hashes mixed in declaration order with a sum's variant index, and lexicographic order asking each field both ways, so Ord does not need Eq.

## Interface
Exports `Ordering`, scalar comparisons, ordering combinators, `Eq`, `Ord`, `Hash`, their generic
helpers, and implementations for compiler-wired scalar/byte types.
## Governance and algorithm
`Eq` defines semantic identity, `Ord` defines relative placement, and `Hash` only selects candidate
buckets. Equal values must hash equally; collisions remain distinct until `Eq` compares them.
`Ord.before` asks whether the left value belongs strictly before the right value. Equal values and
values ordered after the right value both answer `false`. Primitive implementations inherit this
contract text in generated documentation unless a concrete implementation supplies its own note.
## Primitive implementation documentation

Resolved Grill Log: explicit primitive implementations supply the leaf equality, ordering and
hashing operations used by aggregate derive strategies. The source and generated documentation
state that boundary without claiming Pudu lacks deriving. This issue changes only comments.
The existing module exceeds the default size; expanding or extracting its implementations is
outside this bounded documentation repair. [[Std Num]] shares the primitive-capability boundary.
[[2026-10-07-derive-documentation]] records validation and review status.

## Grill Log
- **Q:** Put `Hash` inside `Std.HashMap`? **A:** No. _Rationale:_ the law belongs to the key type and
  is reusable by every hashed collection. _Rejected:_ treating SHA-256 as the trait operation.
- **Q:** Repeat `Ord.before` documentation on every primitive implementation? **A:** No.
  _Rationale:_ the strict-order contract belongs to the trait member and generated documentation
  can inherit it precisely through the named trait. _Rejected:_ copied comments that can drift.

Resolved Grill Log: `Ord.before` owns the strict-order explanation; implementation-specific text
remains an explicit override.
- **Q:** Combine hashes with arithmetic? **A:** No; integer arithmetic traps on overflow, so hashes combine with `^` and `mixHash`.

## Referenced by
[[src/Std/_MOC]] · [[Std HashMap]] · [[ADR-0015-hash-contract-and-hash-map]]
