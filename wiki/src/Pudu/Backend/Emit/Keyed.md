---
type: module
path: "@root/src/Pudu/Backend/Emit/Keyed.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Keyed]
---
# Backend Emit Keyed

## Purpose and interface

`mapHelpers` and `setHelpers`: the C helpers one map or set type needs,
written in terms of its key and value types over [[Native Persistent Trees]].
A map or set is a box whose first cell holds the tree's root.

## Helpers

Word-map algebra (#810): emit one wrapper per operation only for maps whose
value kind is exactly UInt64. Each wrapper selects tree_word_algebra, its
type's ops table and wrap helper. Resolved Grill Log: four closed operation
codes select defined uint64_t bitwise operations; other map kinds gain no
word helper. Preserve the existing map/set helper inventory.

The ops table is assembled from per-type functions: the key order is
`memberCompare` (so `compareValues`), and retaining and releasing follow the
cell's type. Construction folds inserts over an array in order, which is what
`buildMap` and `buildSet` amount to: the first key stays and the last value
wins, and a set keeps its first member. `merge` inserts the right map's
entries replacing keys and values; `union` inserts the right set's members
keeping the left's; `intersect` and `difference` rebuild from the left set.
`keys`, `values`, `entries` and `toArray` walk the tree in order into a new
array. Equality is sizes, then entries pairwise by `memberEqual`; ordering
compares entries in order by key, then value, then size, as `compareEntries`
does; a map or set is comparable when every key and value is.

## Resolved Grill Log

- **Q:** Why does each per-type function get its own helper? **A:** The
  emitter declares every helper's first function before any definition, so
  helpers of different types can call each other in any order. A helper body
  with two functions would leave the second undeclared.
- **Q:** Why is `entries` a tuple array? **A:** `mapEntriesArray` answers
  `(key, value)` tuples, so the map type lists that tuple among its members
  and its helpers exist whenever the map's do.

## Dependencies and consumers

[[Backend Emit Cell]] · [[Native Persistent Trees]] · [[Backend Runtime Array]]

## Referenced by

[[Native Aggregate Emission]] · [[Native Maps and Sets]] · [[src/Pudu/Backend/_MOC]]

## Query contract (#814)

Emit Bool predicate and UInt128 count wrappers only for UInt64 payload maps; emit members only for UInt64 keys too. Select only the used kernel, typed key ops when comparing, and ordinary array ownership for member results. Standalone callable entries must compile without unused-helper warnings.

Resolved Grill Log: project existing checked semantics; no inference, fallback, unsafe cell reinterpretation or frame ABI change. Reuse granular runtime dependencies and existing numeric/array ownership kernels.

## Indexed stores (#840)

entryHelpers builds the map-shaped helper family with its opening and closing text; mapHelpers uses `{`/`}` and storeHelpers `#[`/`]` at key Int. `put` inserts with key replacement. Resolved Grill Log: one family for both, so equality, order, comparability and cleanup cannot differ.
