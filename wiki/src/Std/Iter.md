---
type: module
path: "@root/lib/Std/Iter.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, iteration]
aliases: [Std Iter]
---
# Std Iter
## Purpose
Define the open `Sequence[S, T]` protocol and lazy range, item, map, filter, take, drop, and zip sequences.
## Interface
Exports `Sequence`, sequence value types and constructors, plus `toArray`, `count`, `isEmpty`, and `sum` terminals.
## Governance and algorithm
State is passed rather than mutated; adapters defer work until `advance`, and terminals consume one step at a time without assuming a concrete collection.
## Grill Log
- **Q:** Why expose state in the protocol? **A:** A sequence stays restartable ordinary data and needs no hidden mutable iterator. _Rejected:_ object-local cursor state.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
