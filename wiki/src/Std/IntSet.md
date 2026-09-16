---
type: module
path: "@root/lib/Std/IntSet.pudu"
fidelity: Active
tags: [module, stdlib, set, patricia-trie, data-structures]
aliases: [Std IntSet]
---
# Std IntSet

## Purpose

Provide a high-performance, cache-friendly, purely functional bitwise integer set (Patricia Trie),
inspired directly by Haskell's standard `Data.IntSet` (`containers`, Okasaki & Gill).
Specialized for 64-bit integer elements, avoiding hashing collisions, tree rotation rebalancing, and expensive object comparisons.

## Interface

### Types
- `IntSet`: An immutable bitwise integer trie storing 64-bit integer values.

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

Unlike comparison-based binary search trees (AVL or Red-Black) requiring $O(\log N)$ comparisons and balancing rotations,
`IntSet` partitions elements by their binary representation (bits).
Branching occurs on the highest bit where two subtrees differ (`branchingBit`), computed efficiently using bitwise XOR and highest-bit extraction.
Signed 64-bit integer values (two's complement) are supported naturally:
when the sign bit (bit 63) differs, the critical mask is `-9223372036854775808` (`0x8000_0000_0000_0000`), partitioning negative values into the right child and non-negative values into the left child.
Collection functions (`toArray`) and extreme queries (`findMin`, `findMax`) traverse the sign-bit branch in numerical order (negative subtree before non-negative subtree), ensuring exact sorted ordering across the entire $[-2^{63}, 2^{63}-1]$ domain.
All operations run in $O(\min(N, W))$ time where $W = 64$ is the bit width of the integer.

## Grill Log

- **Q:** Why a dedicated `IntSet` when generic `Set[T: Ord]` exists?
  **A:** Generic `Set[T]` uses binary search trees with dynamic dispatch and ordering comparisons on every node traversal. `IntSet` executes hardware-level bitwise operations (`XOR`, shifts, bit tests) without comparator calls, providing dramatic speedups and zero allocations on failed lookups.
- **Q:** How are negative integers handled at the root?
  **A:** Bit 63 is the sign bit. When comparing two prefixes with different signs, the branching mask is `0x8000_0000_0000_0000` (`-9223372036854775808`). Because two's complement maps negative integers to bit 63 set, ordering traversal visits the right branch (negative numbers) before the left branch (non-negative numbers).
- **Q:** Does `fromArray` sort the input array?
  **A:** No, `fromArray` constructs the Patricia Trie through incremental bitwise insertions in $O(N \cdot W)$, producing a naturally sorted representation when traversed with `toArray`.

## Referenced by

[[src/Std/_MOC]] · [[Std IntMap]] · [[architecture/STDLIB]]
