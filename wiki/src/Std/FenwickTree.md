---
type: module
path: "@root/lib/Std/FenwickTree.pudu"
fidelity: Active
tags: [module, stdlib, fenwick, binary-indexed-tree, prefix-sum, low-level, data-structures]
aliases: [Std FenwickTree]
---
# Std FenwickTree

## Purpose

Provide a low-level, cache-conscious Binary Indexed Tree (Fenwick Tree) inspired by Haskell `Data.FenwickTree` (Hoogle / Hackage).
Supports $O(\log n)$ point updates, $O(\log n)$ cumulative prefix sums, $O(\log n)$ range queries, and $O(\log n)$ binary lifting search over 1-based integer sequences using hardware bitwise arithmetic.

## Interface

### Types
- `FenwickTree = { tree: Array[Int], size: Int }`: Binary indexed tree with 1-based internal storage of size $N+1$.

### Constructors
- `create(size: Int) -> FenwickTree`: Allocates a zero-initialized Fenwick tree for sequence length `size`.
- `fromArray(values: &Array[Int]) -> FenwickTree`: Builds a Fenwick tree in strict $O(n)$ linear time from an array of initial values.

### Operations
- `add(ft: &FenwickTree, index: Int, delta: Int) -> Option[FenwickTree]`: Adds `delta` to the 1-based element at `index` in $O(\log n)$ time. Returns `None` if `index < 1` or `index > size`.
- `set(ft: &FenwickTree, index: Int, value: Int) -> Option[FenwickTree]`: Sets the 1-based element at `index` to `value` by computing the difference from current value.
- `prefixSum(ft: &FenwickTree, index: Int) -> Option[Int]`: Computes $\sum_{k=1}^{\text{index}} A[k]$ in $O(\log n)$ time. Returns `Some(0)` for `index == 0`, and `None` if out of bounds.
- `rangeSum(ft: &FenwickTree, left: Int, right: Int) -> Option[Int]`: Computes $\sum_{k=\text{left}}^{\text{right}} A[k]$ in $O(\log n)$ time via prefix difference. Returns `None` if `left < 1` or `left > right` or `right > size`.
- `get(ft: &FenwickTree, index: Int) -> Option[Int]`: Returns the single element at 1-based `index` in $O(\log n)$ time.
- `findPrefix(ft: &FenwickTree, targetSum: Int) -> Option[Int]`: Finds the smallest 1-based index whose prefix sum is $\ge \text{targetSum}$ in $O(\log n)$ time via binary lifting. Returns `None` if the cumulative sum is less than `targetSum`.
- `size(ft: &FenwickTree) -> Int`: Total number of elements in the tree.
- `toArray(ft: &FenwickTree) -> Array[Int]`: Reconstructs the original 0-indexed values array in $O(n \log n)$ or $O(n)$ time.

## Algorithm and boundaries

Internal representation stores tree values at 1-based indices $1 \dots N$. Index 0 is reserved as dummy root.
- **Lowest set bit isolation:** $i \mathbin{\&} (0 \mathrel{\&-} i)$ isolates the least significant 1-bit of $i$.
- **Point Update:** Adds delta to tree node $i$, then advances to parent $i \mathrel{\&+} (i \mathbin{\&} (0 \mathrel{\&-} i))$ until $i > N$.
- **Prefix Sum:** Accumulates tree node $i$, then steps to predecessor $i \mathrel{\&-} (i \mathbin{\&} (0 \mathrel{\&-} i))$ until $i = 0$.
- **Binary Lifting:** Descends powers of 2 from $\lfloor \log_2 N \rfloor$ to $0$, accumulating prefix intervals without redundant tree queries, yielding strict $O(\log n)$ search.

## Grill Log

- **Q:** Why use 1-based indexing for the public API?
  **A:** Fenwick trees inherently rely on 1-based bit manipulation: $0 \mathbin{\&} (-0) = 0$, which causes infinite loops if 0 is used as a data index. 1-based indexing prevents off-by-one errors and reflects mathematical literature. `prefixSum(0)` explicitly returns `Some(0)`.
- **Q:** Why use wrapping arithmetic `&+` and `&-`?
  **A:** Bitwise two's complement lowest set bit isolation `0 &- i` produces $-i$ without checked integer overflow traps when negating. Point and prefix updates also avoid runtime crashes on cumulative values.

## Referenced by

[[src/Std/_MOC]] · [[Std BitVector]] · [[architecture/STDLIB]]
