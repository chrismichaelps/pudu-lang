---
type: module
path: "@root/src/Pudu/Eval/Array.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.50
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.7
tags: [module, medium]
aliases: [Eval Array]
---

# Eval Array

## Purpose

Own Array runtime semantics for [[Evaluator]]: construction, indexing, iteration support, and accessor methods. Backed by `Data.Sequence` (fingertree) for O(1) append/prepend, O(log n) index access and modify, and structural sharing so immutable updates never copy the entire collection.

## Interface

Exports `arrayFromList`, `arrayToList`, `arrayLength`, `arrayIndex`, `arrayPush`, `arrayPop`, `arrayInsert`, `arrayRemove`, `arraySlice`, `arrayReverse`, `arrayIndexOf`, `arrayContains` — pure functions over `Seq Value`. [[Evaluator]] and [[Eval Dispatch]] are the only consumers.

### Governance

- Data and mechanics only: nothing here decides program meaning that [[architecture/SEMANTICS]] assigns to another phase.
- Failures are reported as `E7xxx` diagnostics through [[Eval Env]], never as host exceptions or partial values.
- Every operation is defined for the value shapes the evaluator can produce, and says so explicitly for the shapes it cannot.

### Linkage

- **Requires:** [[Eval Value]], [[Eval Env]], [[Diagnostic Model]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Direct structural recursion over the `Seq Value` or method name. No caching, no mutation, no reflection. All updates return a new `Seq` — the old value is unchanged, enabling safe structural sharing.

## Array methods

### Core accessors

| Method | Signature | Semantics |
|--------|-----------|-----------|
| `length()` | `fn() -> Int` | O(1) element count |
| `get(i)` | `fn(Int) -> T` | O(log n) indexed read; out-of-bounds is E7004 |
| `indexOf(x)` | `fn(T) -> Int` | O(n) linear search; returns -1 when absent |
| `contains(x)` | `fn(T) -> Bool` | O(n) linear search |

### Mutation (returns new array)

| Method | Signature | Semantics |
|--------|-----------|-----------|
| `push(x)` | `fn(T) -> Array[T]` | O(1) append, returns new array |
| `pop()` | `fn() -> Array[T]` | O(1) drop last, returns new array |
| `insert(i, x)` | `fn(Int, T) -> Array[T]` | O(log n) insert at index |
| `remove(i)` | `fn(Int) -> Array[T]` | O(log n) remove at index |
| `slice(i, j)` | `fn(Int, Int) -> Array[T]` | O(log n) subsequence [i, j) |
| `reverse()` | `fn() -> Array[T]` | O(n) reversed array |

### Higher-order

| Method | Signature | Semantics |
|--------|-----------|-----------|
| `map(f)` | `fn(fn(T) -> U) -> Array[U]` | O(n) apply f to each |
| `filter(f)` | `fn(fn(T) -> Bool) -> Array[T]` | O(n) keep matching |
| `reduce(f, init)` | `fn(fn(A, T) -> A, A) -> A` | O(n) left fold |

Additional methods (`forEach`, `flatMap`, `foldl`, `foldr`, `find`, `findIndex`, `some`, `every`, `count`, `partition`, `concat`, `prepend`, `fill`, `range`, `sum`, `product`, `min`, `max`, `sort`, `sortBy`, `unique`, `take`, `drop`, `join`) are planned for a follow-up issue.

## Negative Logic (Prohibited Paths)

- No typing, coercion, IO, or ownership behaviour.
- No mutation of the input sequence — every method returns a new value.
- No lazy evaluation or memoization — arrays are strict values.

## Edge Cases

- Indexing an empty array is E7004 (index out of range).
- `pop` on an empty array returns an empty array (no error — it is a no-op).
- `slice` with i > j returns an empty array.
- `indexOf` and `contains` use structural equality (`==`), so nested arrays and records work.

## Depth

DEPTH 0.50 (MEDIUM). It keeps array semantics out of [[Evaluator]] and [[Eval Operator]], both of which would exceed the size the delivery rules allow without this split.

## Grill Log

- **Q:** Why `Data.Sequence` rather than `Data.Vector`? **A:** `Data.Sequence` gives O(1) append/prepend and O(log n) split/concat which `Data.Vector` cannot match without copying. For a persistent immutable array with frequent push/insert/remove, structural sharing matters more than cache locality. _Rationale:_ Pudu's ownership model favors immutable updates; structural sharing makes them cheap. _Rejected:_ `Data.Vector` (copying on every update), plain lists (O(n) index).

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]]
