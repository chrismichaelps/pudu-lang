---
type: module
path: "@root/lib/Std/DisjointSet.pudu"
fidelity: Active
tags: [module, stdlib, disjoint-set, union-find, graph, connectivity, low-level, data-structures]
aliases: [Std DisjointSet]
---
# Std DisjointSet

## Purpose

Provide a cache-efficient, low-level Disjoint-Set (Union-Find) data structure inspired by Java (`java.util` graph utilities) and Haskell `Data.DisjointSet` (Hoogle / Hackage).
Backed by flat, unboxed contiguous arrays (`parent`, `rank`, `size`) with iterative path compression and union-by-rank, delivering amortized $O(\alpha(n))$ time complexity without recursive call-stack allocations.

## Interface

### Types
- `DisjointSet = { parent: Array[Int], rank: Array[Int], size: Array[Int], count: Int }`: Union-find state over $N$ contiguous integer elements ($0 \dots N-1$).

### Constructors
- `create(totalElements: Int) -> DisjointSet`: Allocates a disjoint-set forest of $N$ disjoint singleton sets where each element is initially its own representative.

### Operations
- `find(ds: &DisjointSet, x: Int) -> (DisjointSet, Option[Int])`: Finds the representative (root) of element $x$ with two-pass path compression (halving). Returns updated disjoint-set state and root identifier, or `(ds, None)` if out of bounds.
- `union(ds: &DisjointSet, x: Int, y: Int) -> Option[DisjointSet]`: Merges the sets containing $x$ and $y$ using union-by-rank. Returns the updated disjoint set, or unchanged state if already connected. Returns `None` if either index is out of bounds.
- `connected(ds: &DisjointSet, x: Int, y: Int) -> Option[Bool]`: Tests whether elements $x$ and $y$ belong to the same connected component.
- `componentCount(ds: &DisjointSet) -> Int`: Total number of independent connected components remaining.
- `componentSize(ds: &DisjointSet, x: Int) -> Option[Int]`: Returns the number of elements in the component containing $x$.
- `elementCount(ds: &DisjointSet) -> Int`: Total number of elements tracked.

## Algorithm and boundaries

1. **Flat Contiguous Memory:**
   No pointers, node references, or tree heap objects. Indices $0 \dots N-1$ map directly into flat primitive arrays `parent`, `rank`, and `size`.
2. **Iterative Path Halving:**
   During `find`, each node encountered along the search path points to its grandparent:
   $$\text{parent}[i] = \text{parent}[\text{parent}[i]]$$
   This flattens the tree iteratively in a single cache-conscious forward pass without recursive call stack frames.
3. **Union by Rank:**
   When merging two trees with different ranks, the shallower tree is attached under the deeper tree, guaranteeing the tree depth never exceeds $O(\log N)$. With path halving, operations run in $O(\alpha(N))$ time, where $\alpha$ is the extremely slow-growing inverse Ackermann function ($\alpha(N) < 5$ for all practical inputs).

## Grill Log

- **Q:** Why return an updated `DisjointSet` on `find`?
  **A:** Path compression modifies the internal `parent` array to flatten trees for subsequent queries. In an immutable/persistent model, returning `(DisjointSet, Option[Int])` preserves functional purity while maintaining amortized $O(\alpha(N))$ performance.
- **Q:** Why use iterative path halving instead of full recursive path compression?
  **A:** Recursive path compression risks call-stack overflow on deep chains and causes CPU pipeline stalls from deep call returns. Iterative path halving runs in a tight, unrolled loop that executes in hardware registers.

## Referenced by

[[src/Std/_MOC]] · [[Std Graph]] · [[architecture/STDLIB]]
