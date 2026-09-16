---
type: module
path: "@root/lib/Std/Result.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, result]
aliases: [Std Result]
---
# Std Result
## Purpose
Compose, inspect, transform, collect, and traverse recoverable `Result[T, E]` values.
## Interface
Exports predicates, conversions, `map`/`mapErr`/`andThen`, folds, collection helpers, `map2`, `require`, and `traverse`.
## Governance and algorithm
Combinators preserve failures unless their names explicitly discard or transform them; pass-through paths use `?`, while decisions retain `match`.
## Grill Log
- **Q:** Why may `unwrapOr` discard a failure? **A:** Its fallback makes that loss explicit in the name and call. _Rejected:_ hidden extraction that can fail.
## Referenced by
[[src/Std/_MOC]] · [[ADR-0011 Propagation Over Re-Matching]]
