---
type: module
path: "@root/lib/Std/LinkedMap.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.4
depth_status: MEDIUM
coupling: 1.0
interface_stability: 0.8
tags: [module, stdlib, medium]
aliases: [Std LinkedMap]
---

# Std LinkedMap

## Purpose

A map that also remembers the order its keys were first inserted in, and iterates that way.

## Interface

27 exports: the `LinkedMap[K, V]` type, construction (`empty`, `fromPairs`), the ordinary map
surface (`get`, `getOr`, `containsKey`, `insert`, `remove`, `size`, `isEmpty`, `insertIfAbsent`,
`upsert`, `mapValues`, `filter`, `fold`, `merge`, `all`, `any`), order-aware reads (`keys`,
`values`, `pairs`, `oldest`, `newest`, `removeOldest`, `reversed`), the recency form (`touch`), and
`toMap`.

### Governance

- The order is of **first** insertion. Writing to a key already present changes its value and leaves
  its position alone. That is what separates this from a recency order, and it is what a person
  means: a setting does not move to the bottom of a file because it was edited.
- `touch` is the recency form, spelled differently because it answers a different question. A cache
  choosing what to discard wants the key it just wrote to be last; a configuration file does not.
- This is deliberately **not** the default map. [[Eval Keyed]] settled that two maps with the same
  entries must be the same map however they were built, which insertion order would break, and
  recorded that a separate ordered-map type remained open. This is that type.
- `toMap` is named rather than implicit. The entries are the same and only the promise about their
  order differs, and a conversion a reader cannot see is a promise dropped silently.
- No partial functions. `oldest` and `newest` answer `Option`.

### Linkage

- **Requires:** [[Std List]].
- **Consumed by:** programs; nothing in `Std` depends on it.

## Algorithm

An array of keys in insertion order beside an ordinary `Map` holding the entries. The map answers
every question about a key, and the array answers the one question the map gave up. Reads that must
be ordered walk the array and ask the map for each value.

This is what a caller would otherwise keep by hand, and the reason to have it is that keeping the
two in step is the part that gets forgotten: every operation here that changes one changes the
other.

## Negative Logic (Prohibited Paths)

- No reordering on write. `insert` must not move a key that is already present.
- No key in the order without an entry in the map, and none in the map without a place in the order.
- No implicit conversion to `Map`, which would drop the ordering promise without the reader seeing.

## Edge Cases

- Re-inserting an existing key leaves both its position and the entry count unchanged.
- Removing a key closes the gap rather than leaving a hole; removing an absent key changes nothing.
- `oldest` and `newest` on an empty map answer `None`.
- `merge` appends the keys the right map introduces, in that map's own order, after the left map's.

## Depth

DEPTH 0.40 (MEDIUM). Two structures kept in step by every operation that touches either.

## Grill Log

- **Q:** Why not make the built-in `Map` insertion-ordered instead? **A:** Because [[Eval Keyed]]
  already answered that, and the answer is load-bearing: two maps with the same entries compare and
  print alike, which they could not if how they were built were visible. _Rejected:_ changing the
  default, which trades a property every program relies on for one some programs want.
- **Q:** Why keep an array of keys rather than storing a sequence number in each value? **A:**
  Because a sequence number makes every ordered read a sort, and makes the value type something the
  caller did not write. _Rejected:_ `Map[K, (Int, V)]`.
- **Q:** Should `insert` move the key to the end, like a cache? **A:** No, and both behaviours ship
  under different names. _Rationale:_ they are different questions — "when did this first appear"
  and "when was this last touched" — and a single function that guessed would be wrong for whichever
  caller did not want that guess. _Rejected:_ one `insert` with a flag, which pushes the same
  decision to every call site.
- **Q:** Is `remove` walking the key array a problem? **A:** It is honest about what it does: the
  order is a sequence, and taking something out of the middle of a sequence moves what follows it.
  _Deferred:_ if a caller turns up removing keys in a loop over a large map, the order can hold
  positions rather than a plain sequence — but that costs on every write, which is the common case,
  to save on removal, which is not.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Eval Keyed]]
