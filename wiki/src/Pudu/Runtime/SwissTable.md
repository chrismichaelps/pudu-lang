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

## Control group design & SWAR parallel probing

Control metadata is packed into 64-bit words (`IntMap Word64`), storing 8 one-byte tags per machine word:
- `0xFF`: Empty slot (terminates probe sequence).
- `0xFE`: Deleted slot / tombstone (probe sequence continues; reusable on insert).
- `0x00 .. 0x7F`: 7-bit hash fingerprint ($H2 = \text{hash} \gg 57$).

Rather than inspecting slots individually, lookups, insertions, and deletions evaluate an entire 8-slot group
simultaneously using SWAR (SIMD Within A Register) arithmetic:
- `matchByte h2 w`: Computes `(diff - 0x0101010101010101) .&. complement diff .&. 0x8080808080808080`, where `diff = w ^ (h2 * 0x0101010101010101)`.
  This sets the MSB of every matching byte in a single instruction cycle.
- `matchEmpty w`: Evaluates `(complement w - 0x0101010101010101) .&. w .&. 0x8080808080808080` to locate `0xFF` bytes in parallel.
- `countTrailingZeros` extracts matching byte offsets in $O(1)$ hardware instructions (`rbit` / `bsf`), jumping directly to candidate slot addresses.

## Grill Log

- **Q:** Why use SWAR group probing over single-slot linear probing? **A:** Single-slot probing performs repeated map lookups and shifts. SWAR tests 8 control tags simultaneously with integer ALU operations, reducing probe loop iterations by up to 8x.
- **Q:** Why use SwissTable control bytes instead of traditional bucket lists? **A:** Bucket lists allocate separate heap nodes and require pointer dereferences. Control bytes allow testing slots in parallel, avoiding 99% of key comparisons and cache misses.
- **Q:** How are collisions and deletions handled? **A:** Group probing continues across tombstones (`0xFE`), and tombstones are recycled during insertions and eliminated during rehash.
- **Q:** When does rehashing occur? **A:** When live entries exceed 75% of capacity, the table doubles in size to preserve $O(1)$ constant-time operations.

## Dependencies and consumers

Consumed by [[Eval SwissTable]], [[Std Internal FlatMap]], and [[Std HashMap]].

## Referenced by

[[src/_MOC]] · [[Backend Representation Specialization]]
