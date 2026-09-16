---
type: module
path: "@root/lib/Std/IntervalTree.pudu"
fidelity: Active
tags: [module, stdlib, interval-tree, range-query, stabbing-query, geometry, low-level]
aliases: [Std IntervalTree]
---
# Std IntervalTree

## Purpose

Provide an augmented 1D Interval Tree for fast stabbing and interval overlap queries, inspired by Haskell `Data.IntervalTree` (Hoogle / Hackage) and Java Guava `RangeSet`.
Indexes closed integer intervals $[low, high]$, augmenting each node with the maximum endpoint of its subtree (`maxHigh`) to enable $O(\log n + k)$ time queries with aggressive branch pruning.

## Interface

### Types
- `Interval = { low: Int, high: Int }`: Closed 1D interval where $low \le high$.
- `IntervalNode`: Internal tree node carrying `interval`, `maxHigh`, `left`, and `right` subtrees.
- `IntervalTree`: Tree container tracking root node and total interval count.

### Constructors
- `empty() -> IntervalTree`: Creates an empty interval tree.
- `interval(low: Int, high: Int) -> Option[Interval]`: Validates and creates an interval where $low \le high$. Returns `None` if $low > high$.
- `fromIntervals(intervals: &Array[Interval]) -> IntervalTree`: Builds a balanced interval tree from an array of intervals in $O(n \log n)$ time.

### Queries & Updates
- `insert(tree: &IntervalTree, item: Interval) -> IntervalTree`: Inserts an interval and updates subtree maximum endpoints in $O(\log n)$ time.
- `findOverlaps(tree: &IntervalTree, queryRange: Interval) -> Array[Interval]`: Finds all intervals in the tree overlapping $[queryRange.low, queryRange.high]$ in $O(\log n + k)$ time.
- `pointQuery(tree: &IntervalTree, point: Int) -> Array[Interval]`: Stabbing query finding all intervals containing `point`.
- `hasOverlap(tree: &IntervalTree, queryRange: Interval) -> Bool`: Tests if at least one interval overlaps `queryRange` in $O(\log n)$ time.
- `size(tree: &IntervalTree) -> Int`: Total number of intervals stored.
- `isEmpty(tree: &IntervalTree) -> Bool`: Whether the tree contains no intervals.
- `toIntervals(tree: &IntervalTree) -> Array[Interval]`: Materializes all intervals sorted by `low` endpoint.

## Algorithm and boundaries

1. **Augmented Subtree Maximum:**
   Each node stores:
   $$\text{maxHigh} = \max(\text{node.interval.high}, \text{left.maxHigh}, \text{right.maxHigh})$$
2. **Branch Pruning:**
   When searching for overlaps with $[q_{\text{low}}, q_{\text{high}}]$:
   - If `left` is not empty and $\text{left.maxHigh} \ge q_{\text{low}}$, the left subtree may contain overlapping intervals and is explored.
   - If $\text{node.interval.low} > q_{\text{high}}$, no interval in the right subtree can possibly overlap $q$, and the right subtree is pruned completely.
3. **Overlap Condition:**
   Two intervals $[a_1, a_2]$ and $[b_1, b_2]$ overlap if and only if $a_1 \le b_2 \land b_1 \le a_2$.

## Grill Log

- **Q:** Why augment nodes with `maxHigh`?
  **A:** Without `maxHigh`, searching for overlapping intervals would require visiting every subtree, degrading to $O(N)$ linear scans. `maxHigh` allows entire subtrees to be skipped in $O(1)$ when their maximum extent is strictly less than the query range's lower bound.
- **Q:** Can intervals have negative coordinates?
  **A:** Yes, intervals operate over the full 64-bit signed integer range `Int`.

## Referenced by

[[src/Std/_MOC]] · [[Std Tree]] · [[architecture/STDLIB]]
