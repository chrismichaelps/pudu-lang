---
type: module
path: "@root/src/Pudu/Eval/Keyed.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Eval Keyed]
---

# Eval Keyed

## Purpose

The runtime semantics of `Map[K, V]` and `Set[T]`.

## Interface

### Signatures

```haskell
mapFromEntries :: [(Value, Value)] -> Value
mapGet, mapInsert, mapRemove, mapMerge, mapKeys, mapEntries, mapSize, mapContainsKey
setFromMembers :: [Value] -> Value
setInsert, setRemove, setContains, setMembers, setSize
setUnion, setIntersect, setDifference
```

### Governance

- Entries are kept **sorted by key and free of duplicates**. That invariant is what makes two maps
  with the same entries equal however they were built, which is what a reader expects of a map and
  what the structural equality the language already has would otherwise get wrong.
- A later insertion of an existing key replaces its value, matching every other map a reader has
  used. `merge` lets the right map win, because merging is how an override is applied on top of a
  default and the override is what was written last.
- The three set operations merge two ordered runs in one pass. That is what the sorted invariant is
  for: without it each would be quadratic.
- Every operation answers with a new value. A map that changed in place would make two names for one
  map disagree, which is the same rule every other collection here follows.

### Linkage

- **Requires:** [[Eval Order]], [[Eval Value]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Balanced search trees keyed by [[Eval Order]]'s `OrdValue`, whose `Ord` instance is the runtime's
total order on values. The sorted-and-unique invariant the semantics rest on is held by the
structure's own construction rather than re-established by every operation, so the invariant is
stated once instead of in each traversal.

A key already present keeps the key it was first stored under and takes the new value. That is
`insertWith const` rather than `insert`, which would replace the key as well: two keys can be equal
to the order and still be distinguishable values — `1` and `1.0` compare equal — and a map whose
keys silently changed shape on an overwrite would render differently after a write that a reader
was told only replaced a value.

The three set operations remain single-pass merges of two ordered runs, which is what the ordering
buys; they are now the structure's own union, intersection, and difference rather than hand-written
list merges.

## Negative Logic (Prohibited Paths)

- No insertion of a key the order cannot compare; the evaluator refuses it with `E7008` first.
- No dependence on insertion order for equality, iteration, or rendering.

## Edge Cases

- Merging or unioning with an empty collection answers with the other one unchanged.
- A key removed from a collection that lacks it leaves the collection alone rather than reporting.

## Depth

DEPTH 0.50 (MEDIUM). One invariant, maintained by every operation.

## Grill Log

- **Q:** Why an ordered list rather than a balanced tree? **A:** Because the invariant is the
  semantics and the structure is not. Every operation here states its behaviour in terms of key
  order; swapping in a tree changes the cost and nothing else, and doing it now would add code
  before there is a measurement asking for it. _Deferred:_ revisit when a benchmark shows a keyed
  collection on a hot path. **Resolved (#157):** the measurement arrived. Building n entries and
  reading them back grew at x3.55, x3.92, x4.12 across doublings to 16000, where `bench/README.md`
  reads x2 as linear and sustained x2.4 as not; 16000 entries cost three and a half seconds. The
  tree is now in place and, as the deferral predicted, no caller changed.
- **Q:** Does the tree weaken the equality the list gave? **A:** No. _Rationale:_ equality was never
  the list's to give — it comes from entries being sorted and unique, which the tree holds by
  construction. Two maps with the same entries still compare equal however they were built, and a
  key that the order cannot distinguish still collapses to one entry exactly as before.
- **Q:** Why keep the first key on an overwrite rather than the last? **A:** Because a value that
  compares equal is not a value that is identical, and the write said it was replacing a value.
  _Rejected:_ plain `insert`, which replaces the key too and would let `m.insert(1, a)` followed by
  `m.insert(1.0, b)` change how the map renders.
- **Q:** Should a map be iterable in insertion order? **A:** No. _Rationale:_ then two maps with the
  same entries would render differently and compare unequal, and a reader would have to know how a
  map was built to know what it is. _Rejected:_ an insertion-ordered map as the default; a separate
  ordered-map type remains open.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Order]] · [[Evaluator]]
