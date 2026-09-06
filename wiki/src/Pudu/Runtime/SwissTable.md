---
type: module
path: "@root/src/Pudu/Runtime/SwissTable.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance, hashtable, swisstable]
aliases: [Runtime SwissTable Kernels]
---

# Runtime SwissTable Kernels

## Purpose, interface and invariants

`Pudu.Runtime.SwissTable` implements a high-performance flat hash table using control-byte metadata and SIMD group probing.
It uses 1-byte control metadata per slot to eliminate pointer chasing and avoid false key equality comparisons.

Key operations:
- `emptyTable :: Int -> SwissTable v` initializes a table with power-of-two capacity (minimum 16 slots).
- `lookupTable :: Word64 -> SwissTable v -> Maybe v` locates a value by key using 7-bit fingerprint matching.
- `insertTable :: Word64 -> v -> SwissTable v -> SwissTable v` inserts or updates an entry, resizing at 75% load factor.
- `deleteTable :: Word64 -> SwissTable v -> SwissTable v` marks a slot as a tombstone (`0xFE`).
- `entriesTable :: SwissTable v -> [(Word64, v)]` extracts all live entries.
- `sizeTable :: SwissTable v -> Int` returns the count of live entries in $O(1)$.

## Control group design

Each slot has a 1-byte control tag:
- `0xFF`: Empty slot (terminates probe sequence).
- `0xFE`: Deleted slot / tombstone (probe sequence continues; reusable on insert).
- `0x00 .. 0x7F`: 7-bit hash fingerprint ($H2 = \text{hash} \gg 57$).

On lookup, probe groups inspect control bytes. If the fingerprint matches $H2$, the slot is compared;
if `0xFF` is encountered, the lookup terminates with `Nothing` immediately without touching slot memory.

## Grill Log

- **Q:** Why use SwissTable control bytes instead of traditional bucket lists? **A:** Bucket lists allocate separate heap nodes and require pointer dereferences. Control bytes allow testing slots in parallel, avoiding 99% of key comparisons and cache misses.
- **Q:** How are collisions and deletions handled? **A:** Linear triangular probing continues across tombstones (`0xFE`), and tombstones are recycled during insertions and eliminated during rehash.
- **Q:** When does rehashing occur? **A:** When live entries exceed 75% of capacity, the table doubles in size to preserve $O(1)$ constant-time operations.

## Dependencies and consumers

Consumed by [[Eval SwissTable]], [[Std Internal FlatMap]], and [[Std HashMap]].

## Referenced by

[[src/_MOC]] · [[Backend Representation Specialization]]
