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
| tree | the node type, ops table, release, height and size |
| tree_retain | retain a shared tree root |
| tree_node | `pudu_tree_make` |
| tree_build | shared-node opening and `pudu_tree_balance` |
| tree_find | lookup by key |
| tree_insert | insert, keeping or replacing an equal key |
| tree_remove | remove, untouched when the key is absent |
| tree_walk | the nodes in ascending order |

## Ownership

## Word-map algebra (#810)

tree_word_algebra borrows ascending node views, merges once into owned
key/UInt64 pairs, and transfers them into a balanced tree. Missing words
mean zero; zero results disappear; matched entries retain the left key.
Capacity sums/products are checked before allocation; the builder's recursion
is logarithmic. Depend explicitly on tree_node, tree_walk and make.
The node constructor is a separate part so a standalone algebra callable
does not select unused balancing functions. Root retention is also separate;
tree_build selects it, while the borrowing word kernel does not.

Resolved Grill Log: O(n+m) work/storage, no insertion-loop substitute. Retain
each surviving key once, borrow inputs without mutation, free temporary views
and pairs, and let ordinary tree release own the result. This internal helper
requires validated UInt64 payloads and does not change the cell/tree ABI.

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
