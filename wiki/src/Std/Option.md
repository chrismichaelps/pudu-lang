---
type: module
path: "@root/lib/Std/Option.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, option]
aliases: [Std Option]
---
# Std Option
## Purpose
Compose, inspect, transform, collect, and convert optional `Option[T]` values.
## Interface
Exports predicates, fallbacks, `map`/`andThen`, folds, filters, conversions, zipping, collection helpers, and conditional construction.
## Governance and algorithm
Absence propagates with `?` when no decision is made; explicit fallback and conversion functions name when absence is discarded or becomes an error.
## Grill Log
- **Q:** Why are these module functions rather than methods? **A:** `Option` is an ordinary sum with no `impl`; the language contract makes that call shape explicit. _Rejected:_ compiler-only method magic.
## Referenced by
[[src/Std/_MOC]] · [[ADR-0011 Propagation Over Re-Matching]]
