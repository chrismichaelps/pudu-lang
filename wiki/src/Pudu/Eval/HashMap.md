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

## Direct enumeration continuation

Runtime collection enumeration builds output sequences directly with ascending strict folds.
Map values no longer construct key/value pairs merely to discard keys. Map keys, entries, set
members and indexed-bucket enumeration retain their previous ordering and value representation.
Legacy list-returning keyed helpers remain for callers that require lists.

### Resolved Grill Log
- **Q:** Allocate intermediate key/value pairs to return values? **A:** No; traverse payloads directly.
- **Q:** Change enumeration order for a faster layout? **A:** No; the native ascending fold preserves the existing order.
