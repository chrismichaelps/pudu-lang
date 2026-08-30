---
type: module
path: "@root/lib/Std/Math.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, math]
aliases: [Std Math]
---
# Std Math
## Purpose
Provide generic ordered whole-number algorithms through numeric traits rather than one concrete width.
## Interface
Exports ordering helpers, arithmetic conveniences, checked division/powers/root, parity, gcd/lcm, factorial, primality, digit counting, and comparator-based extrema.
## Governance and algorithm
Partial numeric questions return `Option`; algorithms operate through declared `Std.Num` and `Std.Order` traits so caller widths are preserved.
## Grill Log
- **Q:** Why does division return `Option`? **A:** A zero divisor is an ordinary absent result here, not a hidden panic. _Rejected:_ partial library functions.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
