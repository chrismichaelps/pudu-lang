---
type: module
path: "@root/lib/Std/BiMap.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 0.0
interface_stability: 0.8
tags: [module, stdlib, medium]
aliases: [Std BiMap]
---

# Std BiMap

## Purpose

A pairing of two values that can be read from either side, and stays a bijection through every
write.

## Interface

24 exports: the `BiMap[L, R]` type, construction (`empty`, `fromPairs`, `fromPairsChecked`), reads
(`getLeft`, `getRight`, `containsLeft`, `containsRight`, `lefts`, `rights`, `pairs`, `size`,
`isEmpty`), writes (`insert`, `insertChecked`, `removeLeft`, `removeRight`, `merge`, `filter`), and
`flipped`, `toMap`, `fold`, `all`, `any`.

### Governance

- **Both sides are unique.** That is the whole type. A value that could appear twice would make the
  reverse direction not a map, and the reverse direction is the reason to use this.
- `insert` **displaces**. Adding a pair whose left or right side is already bound removes the old
  binding entirely, so the map can end up the same size or smaller after an insert. This is the one
  surprise in the module and it is documented on the function.
- `insertChecked` and `fromPairsChecked` report instead of displacing, for callers whose input was
  meant to already be a bijection and for whom a collision means the data is wrong.
- The two directions are written together by every operation, so they cannot come apart. That is the
  service being offered — a caller keeping two maps by hand has two writes to remember.
- No partial functions.

### Linkage

- **Requires:** nothing beyond the prelude.
- **Consumed by:** programs; nothing in `Std` depends on it.

## Algorithm

Two `Map`s, one each way. `insert` clears both sides of their old bindings first and then writes
both directions, which is what makes the displacing behaviour fall out rather than being a special
case. `flipped` exchanges the two fields and costs nothing, because both directions are already
held — that is the operation an ordinary map cannot offer without rebuilding.

## Negative Logic (Prohibited Paths)

- No state where one direction holds a pair the other does not.
- No `insert` that leaves two left values bound to one right value.
- No scan of one direction to answer a question about the other.

## Edge Cases

- Inserting a pair that collides on both sides at once removes both old pairs and adds one.
- Removing from either side removes the whole pair, never half of it.
- Removing an absent value leaves the map unchanged rather than reporting.
- `fromPairs` may answer a map smaller than the array it was given; `fromPairsChecked` answers
  `None` in exactly those cases.

## Depth

DEPTH 0.45 (MEDIUM). One invariant — both directions agree, both sides unique — held by every write.

## Grill Log

- **Q:** Should `insert` refuse a collision rather than displace? **A:** Not as the default.
  _Rationale:_ the commonest use is maintaining a current pairing — this session now belongs to that
  user — where displacing is exactly what was meant, and forcing a `Result` there would put error
  handling at every call site that has nothing to do about it. _Rejected:_ a single checked
  `insert`; both behaviours ship, under names that say which is which.
- **Q:** Why not one `Map` plus a scan for the reverse? **A:** Because the reverse lookup is the
  reason the type exists, and a scan makes it cost the size of the map. _Rejected:_ a `reversed`
  helper on `Std.Map`, which is the same scan with a shorter name.
- **Q:** Should the two sides be allowed the same type? **A:** Yes, and nothing prevents it.
  _Rationale:_ a synonym table maps text to text, and refusing it would be a restriction with no
  invariant behind it. Uniqueness is per side, so `("a", "a")` is a legal pair.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
