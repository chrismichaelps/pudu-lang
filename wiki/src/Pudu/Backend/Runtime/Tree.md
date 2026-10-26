---
type: module
path: "@root/src/Pudu/Backend/Runtime/Tree.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Persistent Trees]
---
# Native Persistent Trees

## Purpose and interface

Export treeRuntimeParts and treeRuntimeDependencies: one balanced search tree
that every map and set type shares. A node holds a key cell, a value cell
(unused by sets), its two subtrees, its height, the size of its subtree and a
reference count. A `pudu_tree_ops` table supplies the key order and how to
retain and release keys and values, so the tree code is written once.

| Part | Provides |
| --- | --- |
| tree | the node type, ops table, retain/release, height and size |
| tree_build | `pudu_tree_make` and `pudu_tree_balance` |
| tree_find | lookup by key |
| tree_insert | insert, keeping or replacing an equal key |
| tree_remove | remove, untouched when the key is absent |
| tree_walk | the nodes in ascending order |

## Ownership

Every function takes the references it is given and answers with one. A node
is shared between every map that reached it, so a change copies the path from
the root to the change and keeps every other subtree as it is; a node only one
tree holds is taken apart in place instead of being copied. Either way an
update never changes a map someone else still holds.

## Resolved Grill Log

- **Q:** Why a tree rather than a sorted array or a hash table? **A:** The
  evaluator's maps are persistent balanced trees: every update is logarithmic
  and leaves the old map intact. A sorted array makes building a map quadratic,
  and a hash table loses the key order that rendering, iteration and equality
  depend on.
- **Q:** Which balancing? **A:** Heights may differ by two, as in OCaml's
  `Map`: fewer rotations, the same logarithmic bound. The shape is invisible to
  programs; only the order is observable.
- **Q:** Recursion depth? **A:** Bounded by the height, under a hundred for any
  map that fits in memory.

## Dependencies and consumers

[[Backend Runtime Array]] · [[Native Runtime]]

## Referenced by

[[Backend Emit Keyed]] · [[Backend Frame Program]] · [[Native Maps and Sets]] · [[src/Pudu/Backend/_MOC]]
