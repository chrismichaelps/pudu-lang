---
type: module
path: "@root/lib/Std/IntSet.pudu"
fidelity: Active
tags: [module, stdlib, set, data-structures]
aliases: [Std IntSet]
---
# Std IntSet

## Purpose

A set of whole numbers held in the runtime's own ordered set, `Set[Int]`, so lookup, insertion,
removal, and the set operations run natively while the API stays the one programs already use.
Members come back in ascending order, negative numbers first.

## Interface

### Types
- `IntSet = { held: Set[Int] }`: an immutable set of whole numbers.

### Constructors
- `empty() -> IntSet`: An empty integer set.
- `singleton(value: Int) -> IntSet`: A set containing exactly one integer element.
- `fromArray(values: &Array[Int]) -> IntSet`: Constructs a set from an array of integers.

### Queries
- `size(set: &IntSet) -> Int`: The number of live elements in the set.
- `isEmpty(set: &IntSet) -> Bool`: Whether the set holds zero elements.
- `member(set: &IntSet, value: Int) -> Bool`: Whether `value` is present in the set.
- `findMin(set: &IntSet) -> Option[Int]`: Retrieve the minimum element, or `None` if empty.
- `findMax(set: &IntSet) -> Option[Int]`: Retrieve the maximum element, or `None` if empty.

### Modifications
- `insert(set: &IntSet, value: Int) -> IntSet`: Insert an integer value into the set.
- `delete(set: &IntSet, value: Int) -> IntSet`: Remove an integer value if present.
- `deleteMin(set: &IntSet) -> IntSet`: Remove the minimum element from the set.
- `deleteMax(set: &IntSet) -> IntSet`: Remove the maximum element from the set.

### Set Algebra
- `union(left: &IntSet, right: &IntSet) -> IntSet`: Set union combining all elements from both sets.
- `intersection(left: &IntSet, right: &IntSet) -> IntSet`: Set intersection retaining elements present in both sets.
- `difference(left: &IntSet, right: &IntSet) -> IntSet`: Relative complement (elements in `left` not present in `right`).
- `symmetricDifference(left: &IntSet, right: &IntSet) -> IntSet`: Elements present in either set but not both.
- `isSubsetOf(subset: &IntSet, superset: &IntSet) -> Bool`: Whether every element of `subset` is contained in `superset`.
- `disjoint(left: &IntSet, right: &IntSet) -> Bool`: Whether the two sets share no common elements.

### Partitions & Slicing
- `split(set: &IntSet, pivot: Int) -> (IntSet, IntSet)`: Partitions into elements strictly less than `pivot` and strictly greater than `pivot`.
- `splitMember(set: &IntSet, pivot: Int) -> (IntSet, Bool, IntSet)`: Partitions into strictly smaller elements, presence boolean, and strictly greater elements.
- `filter(set: &IntSet, predicate: fn(Int) -> Bool) -> IntSet`: Keeps elements satisfying the predicate.

### Iteration & Conversion
- `toArray(set: &IntSet) -> Array[Int]`: Ascending sorted array of all elements (negative numbers ordered before non-negative).

## Algorithm and boundaries

Each function is one call on the held value, or one walk over the smaller side for a set operation
the runtime does not offer directly. Extreme queries read the ascending members.

## Grill Log

- **Q:** Why a dedicated `IntSet` when generic `Set[T: Ord]` exists?
  **A:** Generic `Set[T]` uses binary search trees with dynamic dispatch and ordering comparisons on every node traversal. `IntSet` executes hardware-level bitwise operations (`XOR`, shifts, bit tests) without comparator calls, providing dramatic speedups and zero allocations on failed lookups.
- **Q:** How are negative integers handled at the root?
  **A:** Bit 63 is the sign bit. When comparing two prefixes with different signs, the branching mask is `0x8000_0000_0000_0000` (`-9223372036854775808`). Because two's complement maps negative integers to bit 63 set, ordering traversal visits the right branch (negative numbers) before the left branch (non-negative numbers).
- **Q:** Does `fromArray` sort the input array?
  **A:** No, `fromArray` constructs the Patricia Trie through incremental bitwise insertions in $O(N \cdot W)$, producing a naturally sorted representation when traversed with `toArray`.

- **Q:** Keep the Patricia trie written in Pudu? **A:** No. _Rationale:_ every operation walked the
  tree in the interpreter and `size` walked all of it; 80,000 mixed operations on `IntMap` took 22.2 s
  against about 0.7 s on the runtime's set (#424). The earlier rationale above described that trie
  and no longer applies. _Rejected:_ a native trie, which adds runtime code the ordered set already
  covers.
## Referenced by

[[src/Std/_MOC]] · [[Std IntMap]] · [[architecture/STDLIB]]
