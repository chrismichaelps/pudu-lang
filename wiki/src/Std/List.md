---
type: module
path: "@root/lib/Std/List.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, collections]
aliases: [Std List]
---
# Std List
## Purpose
Own the operations over arrays that the built-in methods do not: searching, grouping, windows,
zips, set-like combinations, ordering, and aggregates.
## Interface
Free functions over `&Array[T]`, each answering a new array or value. Ordering is `sortBy`,
`sorted` for a type's own order, `sortOn` for a key, and `mergeBy` for two already ordered arrays.
## Governance and algorithm
`sortBy` is the native `Array.sortBy` of [[Eval Sort]]: stable, and one pass for input already in
order or reversed. `sorted` passes the type's `before`. `sortOn` draws each key once, sorts the
key and element pairs, and keeps the elements. `distinct`, `union`, `difference`, and
`intersection` decide membership through a set rather than scanning an array; `union` keeps the
first array whole, duplicates included, as documented.
## Grill Log
- **Q:** Keep the merge sort written in this module? **A:** No. _Rationale:_ the interpreted merge
  dominated the cost of every ordering here. _Rejected:_ a second, Pudu-level fast path.
- **Q:** Let `sortOn` call the key inside the comparison? **A:** No. _Rationale:_ it drew two keys per
  comparison, so an expensive key paid many times over. _Rejected:_ caching keys in a map, which
  needs keys to be orderable twice.
- **Q:** Keep `union` dropping duplicates of the first array? **A:** No. _Rationale:_ its
  documentation and example promised the first array unchanged; the code ran `distinct` over it.
  _Rejected:_ changing the documentation to fit the code, which callers already read.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
