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

Ordered association lists with merge-style traversal. The representation is a list rather than a
balanced tree because the invariant — sorted, unique — is what the semantics need, and the tree is a
performance change that can be made behind this interface without any caller noticing.

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
  collection on a hot path.
- **Q:** Should a map be iterable in insertion order? **A:** No. _Rationale:_ then two maps with the
  same entries would render differently and compare unequal, and a reader would have to know how a
  map was built to know what it is. _Rejected:_ an insertion-ordered map as the default; a separate
  ordered-map type remains open.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Order]] · [[Evaluator]]
