---
type: module
path: "@root/lib/Std/MultiKeyMap.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 0.0
interface_stability: 0.7
tags: [module, stdlib, medium]
aliases: [Std MultiKeyMap]
---

# Std MultiKeyMap

## Purpose

A map keyed by two parts that can also be asked about either part alone.

## Interface

24 exports: the `MultiKeyMap[A, B, V]` type, construction (`empty`, `fromEntries`), whole-key reads
(`get`, `getOr`, `containsKey`), partial reads (`withFirst`, `withSecond`, `secondsFor`,
`firstsFor`, `containsFirst`, `containsSecond`, `firsts`, `seconds`), writes (`insert`, `remove`,
`removeFirst`, `removeSecond`), and `entries`, `values`, `size`, `isEmpty`, `toMap`, `fold`.

### Governance

- **The composite key alone does not justify this module.** `Map[(A, B), V]` already works, because
  the runtime's order handles tuples. A caller who only wants the value under a whole pair should
  write that. This exists for the *partial* question, and that trade-off is documented on the type
  because it is the entire decision of whether to reach for it.
- Two indexes are maintained beside the entries, so **every write updates three structures**. A
  caller who never asks a partial question is paying for indexes they never read.
- The indexes gain an entry only when the key is **new**. Replacing a value leaves them alone: the
  pair they record has not changed, and recording it twice would let a later removal drop one copy
  and leave an index claiming a key the entries no longer hold.
- A key part left naming nothing is dropped from its index, so a partial lookup never reports a part
  with no entries behind it.
- No partial functions.

### Linkage

- **Requires:** nothing beyond the prelude.
- **Consumed by:** programs; nothing in `Std` depends on it.

## Algorithm

`Map[(A, B), V]` for the entries, plus `Map[A, Array[B]]` and `Map[B, Array[A]]` as indexes. A
partial lookup reads the group for the part it was given and asks the entries for each pair, instead
of walking every entry and discarding most of them.

## Negative Logic (Prohibited Paths)

- No index entry without a matching entry in the map, and none missing for an entry that exists.
- No duplicate record of a pair in an index, which a re-insert would otherwise create.
- No key part retained in an index once its last entry is removed.
- No partial answer computed by scanning the entries, which is what the indexes exist to avoid.

## Edge Cases

- Re-inserting an existing key changes the value and leaves both indexes and the size unchanged.
- Removing the last entry under a key part removes that part from its index.
- A partial lookup for an unknown part answers an empty array.
- `removeFirst` and `removeSecond` take every entry under that part, leaving neither index stale.

## Depth

DEPTH 0.50 (MEDIUM). Three structures with one agreement between them, maintained by two writes.

## Grill Log

- **Q:** Is this redundant with tuple keys? **A:** For the whole-key question, yes, and the module
  says so on its own type. _Rationale:_ `Map[(A, B), V]` is valid Pudu today, verified rather than
  assumed, so shipping a module that only wrapped it would add a name and no capability. The partial
  lookup is the capability. _Rejected:_ a `MultiKeyMap` offering only composite keys.
- **Q:** Why two indexes rather than one, or none? **A:** Because both partial questions come up and
  neither is answerable from the other. _Rationale:_ indexing only the first part would make
  "everything for this resource" the scan the module exists to avoid. _Deferred:_ letting a caller
  choose which parts to index, if the write cost of an unused index turns out to matter to someone.
- **Q:** Why two key parts rather than any number? **A:** Because the language has no way to write a
  function over a key of unknown arity, so "any number" would mean an array of parts and lose the
  types of each. _Rejected:_ `Array[Key]` as the key, which trades the type of every part for a
  generality nobody asked for. _Deferred:_ a three-part variant if a caller needs one; the shape
  here does not have to change for that.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
