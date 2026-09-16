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

## Internal collection kernel integration

[[Runtime Collection Kernels]] owns reusable pure storage construction/enumeration; evaluator adapters supply value projections. The module is registered in the compiler library.

### Resolved Grill Log
- **Q:** Duplicate storage loops in each value adapter? **A:** No; share the internal generic kernel without changing public STD behavior.

## Immutable bucket seed

The process seed is a shared NOINLINE Word64 initialized once through the existing entropy
boundary. It is no longer wrapped in an IORef, and bucket mixing does not perform an IORef read.
Entropy selection, the existing fallback constant, word mixing and iteration behavior are unchanged.
This removes mutable storage from the hot path; moving seed ownership into evaluation state remains
a separate architectural task and is not claimed by this change.

### Resolved Grill Log
- **Q:** Keep a mutable reference for a seed that never changes? **A:** No; immutable shared storage expresses the actual lifetime.
- **Q:** Generate a seed on each lookup? **A:** No; a table must retain stable placement for its lifetime.
