---
type: module
path: "@root/lib/Std/IntMap.pudu"
fidelity: Active
tags: [module, stdlib, map, data-structures]
aliases: [Std IntMap]
---
# Std IntMap

## Purpose

A map of whole numbers held in the runtime's own ordered map, `Map[Int, V]`, so lookup, insertion,
removal, and the set operations run natively while the API stays the one programs already use.
Members come back in ascending order, negative numbers first.

## Interface

### Types
- `IntMap[V] = { held: Map[Int, V] }`: an immutable map from whole numbers to values of type `V`.
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

Each function is one call on the held value, or one walk over the smaller side for a set operation
the runtime does not offer directly. Extreme queries read the ascending members.

## Grill Log

- **Q:** Why a bitwise Patricia Trie instead of a hash table?
  **A:** Hash tables suffer from collision probing, clustering, and rehash spikes. `IntMap` is purely functional (zero mutation, structural sharing), sorted by key for free, and outperforms hash maps for integer keys by testing single bits.
- **Q:** How are negative 64-bit integer keys handled without unsigned type primitives?
  **A:** Sign-bit branches (bit 63) are detected when $p_1 \oplus p_2 < 0$. The unsigned mask comparator `higherMask` orders bit 63 above bit 62..0, and tree collections traverse negative keys first to guarantee strictly ascending key order.
- **Q:** What is the behavior on empty maps?
  **A:** Queries return absence (`None`), set operations preserve identities ($M \cup \emptyset = M$, $M \cap \emptyset = \emptyset$, $M \setminus \emptyset = M$), and `delete`/`adjust` are no-ops returning empty maps without allocating.

- **Q:** Keep the Patricia trie written in Pudu? **A:** No. _Rationale:_ every operation walked the
  tree in the interpreter and `size` walked all of it; 80,000 mixed operations on `IntMap` took 22.2 s
  against about 0.7 s on the runtime's map (#424). The earlier rationale above described that trie
  and no longer applies. _Rejected:_ a native trie, which adds runtime code the ordered map already
  covers.
## Referenced by

[[src/Std/_MOC]] · [[Std Map]] · [[Std HashMap]] · [[architecture/STDLIB]]
