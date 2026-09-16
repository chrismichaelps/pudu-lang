---
type: module
path: "@root/src/Pudu/Eval/SwissTable.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance, hashtable, swisstable]
aliases: [Eval SwissTable]
---

# Eval SwissTable

## Purpose, interface and invariants

`Pudu.Eval.SwissTable` adapts [[Runtime SwissTable Kernels]] for the evaluator, providing pure wired-in builtins:
- `callSwissTableEmpty`: Constructs a flat hash table with specified initial capacity.
- `callSwissTableLookup`: Performs SIMD-style fingerprint probing; answers `Option[V]`.
- `callSwissTableInsert`: Inserts or replaces a key-value mapping; rehashes at 75% load factor.
- `callSwissTableDelete`: Deletes a key, inserting a tombstone in the control metadata.
- `callSwissTableEntries`: Materializes all entries into an ascending `Array[(UInt64, V)]`.
- `callSwissTableSize`: Returns the live entry count in $O(1)$.

## Grill Log

- **Q:** Require an opaque un-inspectable runtime value? **A:** No; the table representation is backed by canonical metadata and slot storage, allowing safe cross-boundary serialization and debugging.
- **Q:** How are hash collisions resolved? **A:** 7-bit fingerprint matching filters out 99% of empty or mismatching slots before checking the exact 64-bit key.
- **Q:** How are malformed arguments reported? **A:** Wrong types report E7001; invalid arity reports E7003.

## Dependencies and consumers

- **Requires:** [[Runtime SwissTable Kernels]], [[Eval Env]], [[Eval Value]].
- **Consumed by:** [[Eval Builtin]], [[Std Internal FlatMap]].

## Referenced by

[[src/_MOC]] · [[Backend Representation Specialization]]
