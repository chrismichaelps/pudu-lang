---
type: module
path: "@root/lib/Std/MultiMap.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.4
depth_status: MEDIUM
coupling: 1.0
interface_stability: 0.8
tags: [module, stdlib, medium]
aliases: [Std MultiMap]
---

# Std MultiMap

## Purpose

Several values under one key, with the add, remove, and empty-key bookkeeping done once.

## Interface

30 exports: the `MultiMap[K, V]` type, construction (`empty`, `fromPairs`, `groupBy`), reads (`get`,
`containsKey`, `contains`, `count`, `size`, `total`, `isEmpty`, `keys`, `values`, `pairs`, `groups`),
writes (`add`, `addAll`, `setAll`, `remove`, `removeAll`, `removeKey`), and `mapValues`,
`filterValues`, `filterKeys`, `fold`, `merge`, `inverted`, `toMap`, `all`, `any`.

### Governance

- **A key with no values does not exist.** Every operation maintains it. This is the invariant the
  hand-written version forgets, and the one that makes `size`, `containsKey`, and `keys` mean what a
  reader expects — a key mapped to an empty array is a map disagreeing with itself.
- `get` answers an **empty array**, not `Option[Array[V]]`. A key with no values and a key never
  added are the same state here, and two spellings of one state would invite callers to try to
  distinguish them.
- Values under a key are a **bag**, not a set: order of addition is kept and duplicates are kept.
  The commonest use is collecting records that genuinely repeat — two headers with the same name.
- `remove` takes **one occurrence**; `removeAll` takes every copy. Removing every copy when the
  caller took one back would lose the others.
- `size` counts keys and `total` counts values, matching what `size` means on `Map`.

### Linkage

- **Requires:** [[Std List]].
- **Consumed by:** programs; nothing in `Std` depends on it.

## Algorithm

One `Map[K, Array[V]]`. Every write goes through `setAll`, which is the single place that decides
whether a key survives: given an empty array it removes the key rather than storing one. Routing
`remove`, `removeAll`, and `filterValues` through it is what makes the invariant hold in one place
instead of at four call sites.

## Negative Logic (Prohibited Paths)

- No key stored with an empty array of values.
- No deduplication of values under a key; that is a different structure.
- No `Option` from `get`, which would reintroduce the state the invariant exists to rule out.

## Edge Cases

- Removing the last value under a key removes the key.
- `setAll` with an empty array removes the key rather than storing one.
- `filterValues` rejecting everything under a key drops that key.
- `addAll` with an empty array leaves the map unchanged, and does not create the key.
- `inverted` gives each value a key holding every key it appeared under, which is the reverse index.

## Depth

DEPTH 0.40 (MEDIUM). One invariant, funnelled through one function so it is stated once.

## Grill Log

- **Q:** Why not just use `Map[K, Array[V]]` directly? **A:** Because the four lines around each
  write are the whole content of this module, and the fourth — removing the key when its values run
  out — is the one that gets skipped. _Rationale:_ a type whose invariant is maintained in one place
  cannot be half-maintained at a call site. _Rejected:_ a few helper functions on `Std.Map`, which
  leaves the invariant optional.
- **Q:** Should values under a key be a set? **A:** No. _Rationale:_ the commonest use is collecting
  things that legitimately repeat, and deduplicating silently would lose data the caller gathered.
  _Deferred:_ a distinct set-valued variant if a caller turns up wanting one; `mapValues` over a set
  type is not the same structure and should not share a name.
- **Q:** Why does `get` not answer `Option`? **A:** Because the invariant already rules out the
  state that would make the distinction meaningful. _Rationale:_ if a key with no values cannot
  exist, then "absent" and "present but empty" are one case, and an `Option` would ask the caller to
  handle a branch that never occurs. _Rejected:_ `Option[Array[V]]`.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
