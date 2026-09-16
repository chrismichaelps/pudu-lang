---
type: module
path: "@root/lib/Std/IntMap.pudu"
fidelity: Active
tags: [module, stdlib, map, patricia-trie, data-structures]
aliases: [Std IntMap]
---
# Std IntMap

## Purpose

Provide a high-performance, cache-friendly, purely functional bitwise integer map (Patricia Trie),
inspired directly by Haskell's standard `Data.IntMap` (Okasaki & Gill).
Specialized for 64-bit integer keys, avoiding hash table collisions, rebalancing rotations, and expensive key comparisons.

## Interface

### Types
- `IntMap[V]`: An immutable bitwise integer trie mapping 64-bit integer keys to values of type `V`.
- `IntMapEntry[V] = { key: Int, value: V }`: A key-value pairing.

### Constructors
- `empty[V]() -> IntMap[V]`: An empty integer map.
- `singleton[V](key: Int, value: V) -> IntMap[V]`: A map containing exactly one key-value pairing.

### Queries
- `size[V](map: &IntMap[V]) -> Int`: The number of live entries in the map.
- `isEmpty[V](map: &IntMap[V]) -> Bool`: Whether the map holds zero entries.
- `member[V](map: &IntMap[V], key: Int) -> Bool`: Whether `key` is present.
- `get[V](map: &IntMap[V], key: Int) -> Option[V]`: Retrieve the value associated with `key`.
- `getOr[V](map: &IntMap[V], key: Int, fallback: V) -> V`: Retrieve the value or return `fallback`.
- `minKey[V](map: &IntMap[V]) -> Option[Int]`: Retrieve the minimum key present in the map, or `None` if empty.
- `maxKey[V](map: &IntMap[V]) -> Option[Int]`: Retrieve the maximum key present in the map, or `None` if empty.

### Modifications
- `insert[V](map: &IntMap[V], key: Int, value: V) -> IntMap[V]`: Insert or replace a key-value pairing.
- `delete[V](map: &IntMap[V], key: Int) -> IntMap[V]`: Remove a key-value pairing if present.
- `adjust[V](map: &IntMap[V], key: Int, f: fn(V) -> V) -> IntMap[V]`: Update value under `key` if present.

### Set Operations & Transformations
- `union[V](left: &IntMap[V], right: &IntMap[V]) -> IntMap[V]`: Union of two maps, preferring left on key conflicts.
- `intersection[V](left: &IntMap[V], right: &IntMap[V]) -> IntMap[V]`: Intersection of two maps, retaining left values.
- `difference[V](left: &IntMap[V], right: &IntMap[V]) -> IntMap[V]`: Entries in `left` whose keys do not occur in `right`.
- `mapValues[A, B](map: &IntMap[A], f: fn(A) -> B) -> IntMap[B]`: Transform all values.

### Iteration & Collection
- `keys[V](map: &IntMap[V]) -> Array[Int]`: Ascending sorted array of all keys (negative keys ordered before non-negative).
- `values[V](map: &IntMap[V]) -> Array[V]`: Array of all values in key order.
- `entries[V](map: &IntMap[V]) -> Array[IntMapEntry[V]]`: Array of key-value pairs in key order.

## Algorithm and boundaries

Unlike balanced binary search trees (AVL or Red-Black) which require $O(\log N)$ key comparisons and tree rebalancing,
`IntMap` partitions keys by their binary representation (bits).
Branches occur on the highest bit where two sub-branches differ (`branchingBit`), computed efficiently using bitwise XOR and highest-bit extraction.
Signed 64-bit integer keys (two's complement) are supported naturally:
when the sign bit (bit 63) differs, the critical mask is `-9223372036854775808` (`0x8000_0000_0000_0000`), partitioning negative keys into the right child and non-negative keys into the left child.
Collection functions (`keys`, `values`, `entries`) and extreme queries (`minKey`, `maxKey`) traverse the sign-bit branch in numerical order (negative subtree before non-negative subtree), ensuring exact sorted ordering across the entire $[-2^{63}, 2^{63}-1]$ domain.
Search, insertion, and deletion run in $O(\min(N, W))$ time where $W = 64$ is the bit width of the integer key.

## Grill Log

- **Q:** Why a bitwise Patricia Trie instead of a hash table?
  **A:** Hash tables suffer from collision probing, clustering, and rehash spikes. `IntMap` is purely functional (zero mutation, structural sharing), sorted by key for free, and outperforms hash maps for integer keys by testing single bits.
- **Q:** How are negative 64-bit integer keys handled without unsigned type primitives?
  **A:** Sign-bit branches (bit 63) are detected when $p_1 \oplus p_2 < 0$. The unsigned mask comparator `higherMask` orders bit 63 above bit 62..0, and tree collections traverse negative keys first to guarantee strictly ascending key order.
- **Q:** What is the behavior on empty maps?
  **A:** Queries return absence (`None`), set operations preserve identities ($M \cup \emptyset = M$, $M \cap \emptyset = \emptyset$, $M \setminus \emptyset = M$), and `delete`/`adjust` are no-ops returning empty maps without allocating.

## Referenced by

[[src/Std/_MOC]] · [[Std Map]] · [[Std HashMap]] · [[architecture/STDLIB]]
