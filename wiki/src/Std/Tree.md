---
type: module
path: "@root/lib/Std/Tree.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, stdlib, medium]
aliases: [Std Tree]
---

# Std Tree

## Purpose

One value with a sequence of trees beneath it, and the walks, transformations, and searches worth
asking of that shape.

## Interface

40 exports: the `Tree[T]` and `Forest[T]` types, construction (`leaf`, `node`, `withChild`,
`unfold`, `unfoldTo`, `unfoldForest`), projections (`valueOf`, `childrenOf`, `isLeaf`, `degree`),
measures (`size`, `height`), traversals (`preorder`, `postorder`, `levels`, `breadthFirst`,
`leaves`), transformations (`map`, `mapWithPath`, `mapResult`, `mapOption`, `flatMap`, `zipWith`, `prune`, `reversed`), carrier turns (`sequenceResult`, `sequenceOption`, `unfoldResult`), folds (`fold`,
`foldTree`), search and paths (`find`, `contains`, `count`, `pathTo`, `trailTo`, `at`), and
`sameShape`, `outline`.

### Governance

- A node with no children is **not a separate case**; it is a node whose sequence is empty. That is
  what removes the `Option` a hand-written hierarchy carries at every branch.
- Children keep the order they were given, at every depth and in every traversal.
- `height` of a leaf is **1**, and `size` counts the root, so the two never disagree about whether
  the root is a node.
- A **path** is the child index taken at each step from the root, so the root's path is empty. A
  found root is an empty path rather than an absence, which is the distinction `Option` carries.
- `prune` removes a rejected node **with its subtree** rather than promoting its children, which
  would put a node under a parent it never had. A rejected root answers `None`, because a tree with
  no nodes is not a tree.
- `unfold` is bounded by its own `grow`; `unfoldTo` is bounded by a depth. Neither is lazy, and the
  documentation says so rather than implying an infinite tree can be built and consumed.
- No partial functions and no sentinels; every question that may have no answer answers `Option`.

### Linkage

- **Requires:** [[Std List]], [[Std Order]].
- **Consumed by:** programs; nothing in `Std` depends on it.

## Algorithm

Structural recursion for everything that follows the shape, with `levels` the exception: it gathers
a whole depth and makes its children the next depth, which is one pass and needs no queue, and
answers the levels a caller usually wanted anyway.

`foldTree` gives each node its own value and the answers from beneath it. `size`, `height`,
`preorder` and `leaves` are all expressible through it, and are written directly only because the
direct form reads plainly.

## Negative Logic (Prohibited Paths)

- No sorting or reordering of children by any operation that does not say it reorders.
- No promotion of a pruned node's children into its parent.
- No `height` that disagrees with `size` about the root.
- No traversal that answers a nearest node when asked for a missing one.
- No `Functor`, `Foldable`, or `Traversable` facade. Those need a type parameter standing for a type
  constructor, and [[grammar/pudu]] records that v1 has no higher-kinded types. What each of them
  would supply is present under its own name — `map`, `leaf`, `zipWith`, `flatMap`, `fold`,
  `foldTree`, `mapResult`, `mapOption`, `sequenceResult`, `sequenceOption`, `unfoldResult` — because
  they can only be named per type and per carrier, and naming them so is honest where a shared
  facade would not be.

## Edge Cases

- A leaf has size 1, height 1, degree 0, and is its own only level.
- `at` with an empty path answers the whole tree; a path leading nowhere answers `None`.
- `pathTo` matching the root answers an empty path, which is found rather than missing.
- `unfoldTo` with a depth of 1, 0, or less answers a leaf: there is always a root.
- Reversing twice answers the tree it started as.
- `mapResult` stops at the first failure and does not attempt the rest.

## Depth

DEPTH 0.50 (MEDIUM). One shape, one path convention, and a fold the rest follow from.

## Grill Log

- **Q:** Why is `height` of a leaf 1 rather than 0? **A:** So it counts the same things `size`
  counts. _Rationale:_ with 0, a leaf has size 1 and height 0, and every caller has to remember
  which of the two includes the root. _Rejected:_ edge-counting height, which is defensible alone
  and inconsistent beside `size`.
- **Q:** Should `prune` promote the children of a removed node? **A:** No. _Rationale:_ a hierarchy
  means something — a child is under its parent because of a relationship — and promoting a
  grandchild asserts a relationship that was never stated. _Rejected:_ a promoting variant, until a
  caller turns up who wants it and can say what the new edge means.
- **Q:** Why both `fold` and `foldTree`? **A:** They answer different questions. _Rationale:_ `fold`
  is the flat reading, where the shape is gone and the values arrive in preorder; `foldTree` is the
  structural one, where what a node answers depends on what its children answered. Only the second
  can express `height`. _Rejected:_ shipping only `foldTree`, which makes summing a tree read like a
  recursion scheme.
- **Q:** Why is there no `Functor` or `Foldable` implementation? **A:** Because the language cannot
  express one. _Rationale:_ abstracting over "container" needs a type parameter that stands for a
  type constructor, and [[grammar/pudu]] records that v1 has no higher-kinded types; a trait over
  `Tree[_]` cannot be written. _Rejected:_ a same-named set of functions dressed as a shared
  abstraction, which would suggest a generality that no caller could actually use.
- **Q:** If the abstractions cannot be written, why do their operations exist? **A:** Because the
  operations are what callers want and the abstraction is only how they would otherwise be shared.
  _Rationale:_ `flatMap` grafts a tree where a value stood, `zipWith` combines two hierarchies,
  `sequenceResult` turns a tree of results into a result of a tree — each is worth having on its own
  terms, and none of them needs the missing feature. What is lost is writing them once for every
  container, not having them at all. _Rejected:_ omitting them until the language can share them,
  which would leave the type unable to do what the shape is for.
- **Q:** Why is there no breadth-first effectful growth? **A:** Because the order only matters for
  which failure is reported, and each order would need a separate named function for each carrier
  while the language cannot abstract over one. _Rationale:_ depth-first is the order `unfold`
  already grows in, so the failure reported is the one a reader following the tree downward meets
  first, which is the explainable choice. _Deferred:_ a breadth-first variant if a caller needs that
  specific reporting order.
- **Q:** Why does `unfold` not build infinite trees? **A:** Because the language is strict.
  _Rationale:_ elsewhere an infinite unfold is fine because nothing is built until it is demanded;
  here every node is built when it is described, so an unbounded `grow` does not finish. Saying so
  and offering `unfoldTo` is honest; a lazy tree would be a different value than this one.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
