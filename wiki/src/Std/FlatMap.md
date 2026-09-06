---
type: module
path: "@root/lib/Std/FlatMap.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, flatmap, hashtable, performance]
aliases: [Std FlatMap]
---

# Std FlatMap

## Purpose

Ultra-high-performance flat hash table utilizing 1-byte control metadata per slot and 7-bit fingerprint
matching to eliminate pointer chasing and false key comparisons.

## Interface

Exports:
- `FlatMap[V]`: Fast flat hash map mapping `UInt64` keys to arbitrary values `V`.
- `empty(initialCapacity: Int) -> FlatMap[V]`: Construct empty table with power-of-two capacity.
- `size(target: &FlatMap[V]) -> Int`: Number of active pairings.
- `isEmpty(target: &FlatMap[V]) -> Bool`: Check if empty.
- `get(target: &FlatMap[V], key: UInt64) -> Option[V]`: Lookup by 64-bit key.
- `getOr(target: &FlatMap[V], key: UInt64, fallback: V) -> V`: Lookup with fallback.
- `containsKey(target: &FlatMap[V], key: UInt64) -> Bool`: Membership check.
- `insert(target: &FlatMap[V], key: UInt64, value: V) -> FlatMap[V]`: Add or replace pairing.
- `remove(target: &FlatMap[V], key: UInt64) -> FlatMap[V]`: Delete pairing.
- `entries(target: &FlatMap[V]) -> Array[(UInt64, V)]`: Materialize all entries in slot order.

## Governance

- Probing inspects control metadata; 7-bit fingerprint matching avoids evaluating slot keys when absent.
- Automatic rehash triggers when load factor exceeds 75%.
- Pure functional semantics: modifications return a new `FlatMap` snapshot.

## Grill Log

- **Q:** How does FlatMap compare to HashMap? **A:** HashMap uses bucket arrays of entry records; FlatMap stores slots in a flat table with 1-byte control metadata, eliminating intermediate node allocations and reducing cache misses.
- **Q:** Does FlatMap support non-UInt64 keys? **A:** FlatMap specializes on 64-bit keys (such as hashes, IDs, or bitsets); generic keys can be hashed into UInt64 keys.

## Referenced by

[[src/Std/_MOC]] · [[Backend Representation Specialization]] · [[Std HashMap]]
