---
type: module
path: "@root/lib/Std/SortedMap.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 1.0
interface_stability: 0.8
tags: [module, stdlib, medium]
aliases: [Std SortedMap]
---

# Std SortedMap

## Purpose

A map ordered by a comparison the caller supplies, which can be asked about a key's neighbours
rather than only about the key itself.

## Interface

31 exports: the `SortedMap[K, V]` type, construction (`empty`, `fromPairs`), the ordinary map
surface (`get`, `getOr`, `containsKey`, `insert`, `remove`, `keys`, `values`, `pairs`, `size`,
`isEmpty`, `insertIfAbsent`, `upsert`, `mapValues`, `filter`, `fold`, `merge`, `all`, `any`), and
the navigation that is the reason it exists: `floor`, `ceiling`, `lower`, `higher`, `first`, `last`,
`nth`, `range`, `restrictRange`, `reversed`.

### Governance

- The comparison is **carried with the entries**, fixed when the map is created. A map compared one
  way on one call and another way on the next is not a map, and passing the comparison per call
  would make every caller responsible for remembering which one this map was built with.
- The comparison answers whether its first key comes **strictly** before its second. Two keys that
  each come before the other are keys the order cannot distinguish, and this treats keys it cannot
  distinguish as the same key.
- Identity is decided by the **order**, not by equality. A map that located a key by one rule and
  matched it by another could hold a key it could not find.
- `range` is **half-open**: at least `from`, strictly before `until`. Adjacent ranges therefore tile
  without overlap and without a gap.
- `floor` and `ceiling` include an exact hit; `lower` and `higher` exclude it. That is the whole
  difference between the two pairs and the reason both exist.
- No partial functions. Every question about an entry that may not exist answers `Option`.

### Linkage

- **Requires:** [[Std List]].
- **Consumed by:** programs; nothing in `Std` depends on it.

## Algorithm

One array of pairs, held sorted, searched by halving the range. `locate` answers how many entries
come strictly before a key — the insertion point for a key that is absent, and the position of the
key itself for one that is present — and every other operation is stated in terms of it, so one
search serves lookup, insertion, and both neighbour questions.

Insertion and removal move an element into or out of the middle of that array. The runtime's arrays
are finger trees, so that costs about what reading the array costs, which is what makes keeping the
order affordable rather than something paid for at every write.

## Negative Logic (Prohibited Paths)

- No reliance on the runtime's own order on values; the caller's comparison is the only order.
- No comparison passed per operation, which would let one map be read under two different orders.
- No equality test standing in for the order when deciding whether two keys are the same.

## Edge Cases

- `floor` below every key, and `ceiling` above every key, answer `None` rather than a nearest miss.
- A boundary landing exactly on an entry belongs to `floor`/`ceiling` and not to `lower`/`higher`.
- `range` with its bounds reversed is empty rather than the entries between them.
- Re-inserting an existing key replaces its value without changing the number of entries.
- `reversed` carries a comparison that agrees with the new arrangement, so the result is a map that
  still obeys its own order rather than an array that happens to be backwards.

## Depth

DEPTH 0.55 (MEDIUM). One search, one invariant, and every operation expressed through them.

## Grill Log

- **Q:** Why not build this on `Map` and sort on the way out? **A:** Because the questions it exists
  to answer are the ones sorting on the way out is too late for. `floor` on a map of a million
  entries would read all million to find one. _Rejected:_ a wrapper over `Map` with a sort in
  `pairs`.
- **Q:** Why an array rather than a search tree written in Pudu? **A:** Because the runtime's array
  is already a balanced structure, so a tree written on top of it would be a second balanced
  structure over the first, paying twice for one guarantee. _Rejected:_ a hand-written node type,
  which would also make every operation recursive where this one is a loop a reader can follow.
- **Q:** Should the comparison return an `Ordering` rather than a `Bool`? **A:** Not for now. _
  Rationale:_ `before` is the one function a caller must supply, and a boolean "does this come
  first" is the smallest thing that can be asked of them; the two neighbour pairs are already
  expressible from it. _Deferred:_ an `Ordering`-shaped constructor if a caller turns up who needs
  to distinguish "equal" from "neither before the other" — today those are deliberately the same.
- **Q:** Why does `nth` exist on a map? **A:** Because an ordered structure knows which entry is the
  tenth and an unordered one does not, and a caller wanting a median, a percentile, or a page of
  results otherwise reads everything out to count. _Rejected:_ leaving it to the caller, which
  throws away the one thing the ordering already paid for.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
