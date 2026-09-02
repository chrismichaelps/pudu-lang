---
type: module
path: "@root/src/Pudu/Eval/HashMap.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, hash-map]
aliases: [Eval Hash Map]
---
# Eval Hash Map
## Purpose
Own persistent indexed buckets and deterministic insertion order for `Std.HashMap`.
## Interface
Constructs tables and performs lookup, insert, remove, enumeration, size, and equality through
evaluator built-ins whose types require the public `Eq + Hash` contract.
## Governance and algorithm
Bucket placement uses a seeded final mix; key identity calls the selected `Eq` implementation;
enumeration follows stored first-insertion order. Updates return a new value and never mutate an
already-observable map.
## Grill Log
- **Q:** Use rendered value text as key identity? **A:** No. _Rationale:_ rendering is neither the
  type's `Eq` nor collision-safe identity. _Rejected:_ a mutable process-global table per map.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Std HashMap]] · [[Eval Hash]]
