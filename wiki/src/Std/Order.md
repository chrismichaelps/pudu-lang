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
## Grill Log
- **Q:** Put `Hash` inside `Std.HashMap`? **A:** No. _Rationale:_ the law belongs to the key type and
  is reusable by every hashed collection. _Rejected:_ treating SHA-256 as the trait operation.
## Referenced by
[[src/Std/_MOC]] · [[Std HashMap]] · [[ADR-0015-hash-contract-and-hash-map]]
