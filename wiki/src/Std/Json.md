---
type: module
path: "@root/lib/Std/Json.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, json]
aliases: [Std Json]
---
# Std Json
## Purpose
Decode, encode, inspect, and immutably transform JSON values with positioned parse errors.
## Interface
Exports `Json`, `JsonError`, compact/pretty encoding, field/index/path lookup, typed projections, constructors, key updates, and error explanation.
## Governance and algorithm
The recursive reader advances an explicit scalar index, rejects trailing or malformed input as `Result`, and the encoder escapes strings deterministically.
## Grill Log
- **Q:** Why keep objects as ordered pairs? **A:** Encoding remains deterministic and preserves source order while lookup still has an explicit rule. _Rejected:_ host-map ordering.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
