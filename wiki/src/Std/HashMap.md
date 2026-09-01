---
type: module
path: "@root/lib/Std/HashMap.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, hash-map]
aliases: [Std HashMap]
---
# Std HashMap
## Purpose
Provide persistent expected-constant-time key lookup with deterministic insertion-order traversal.
## Interface
The initial surface is empty/singleton/from-array, size/empty, contains/get/get-or,
insert/insert-with/remove, keys/values/entries, map/filter/fold/merge/equality, and ordered conversion.
## Governance and algorithm
Keys require `Eq + Hash`. Runtime bucket storage is opaque and indexed; collisions compare keys with
`Eq`. A separate first-insertion order keeps iteration deterministic across runtime hash seeds.
## Grill Log
- **Q:** Implement with `Map[Int, Array[(K,V)]]`? **A:** No. _Rationale:_ that keeps logarithmic
  bucket selection and adds hashing overhead. _Rejected:_ layout-dependent iteration; partial get.
## Referenced by
[[src/Std/_MOC]] · [[Std Order]] · [[Eval Hash Map]] · [[ADR-0015-hash-contract-and-hash-map]]
