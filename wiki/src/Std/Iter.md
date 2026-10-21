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
Define the open `Sequence[S, T]` protocol, its chainable default adapters and terminals, and lazy range and item sources.
## Interface
Exports `Sequence`, whose default members are the adapters `map`, `filter`, `take`, `drop`, `takeWhile`, `dropWhile`, `stride`, `chain`, `enumerate` and `zip`, and the terminals `toArray`, `count`, `isEmpty`, `fold`, `any`, `all`, `find`, `first` and `last`. Every implementor has them, so a pipeline reads `source.map(f).filter(g).take(3).toArray()`. The adapter types, `range`, `items`, `indexed`, `repeat` and `empty`, and the free functions `map`, `filter`, `take`, `drop`, `zip`, `toArray`, `count`, `isEmpty` and `sum` remain; the free terminals call the methods.
## Governance and algorithm
State is passed rather than mutated; adapters defer work until `advance`, and terminals consume one step at a time without assuming a concrete collection.

- Each source item is produced once. `dropWhile` carries whether it is still dropping in its state instead of reading the first kept item twice, and `stride` and `chain` record that their source has ended so they never ask it again.
- Terminals walk `*self` with `for`, which resolves `begin` and `advance` once per walk; adapters call their source's `advance` directly. Measured at `-O0` on a 400,000-item `range.map.filter.take` pipeline, these together take 16% less time than a hand-written `begin`/`advance` loop with trait-qualified calls; `count()` alone takes 22% less.
- A type that answers a terminal without walking overrides it in its own implementation, as `Std.Span` does for `toArray` and `count`.
## Grill Log
- **Q:** Why expose state in the protocol? **A:** A sequence stays restartable ordinary data and needs no hidden mutable iterator. _Rejected:_ object-local cursor state.
- **Q:** Chain by free functions or methods? **A:** Methods, as default members of `Sequence`: nested free functions read inside out. The free functions stay for existing callers and call the methods. This needed defaults of a generic trait to be typed at the implementation (#528) and inherited across modules (#530). _Rejected:_ an extension trait with a blanket implementation, which the language does not attach to arbitrary implementors.
- **Q:** Clamp or refuse a negative `take`, `drop` or `stride`? **A:** Clamp: `take(-2)` is empty, `drop(-1)` drops nothing, and `stride` below 1 is 1, matching `Str.take` and `Array.slice`.

## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
