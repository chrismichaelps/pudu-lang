---
type: architecture
tags: [backend, native, collections]
aliases: [Native Word Map Algebra]
---
# Native Word Map Algebra

The four sparse word-map operations take identical Map[K, UInt64] inputs
and return that map type. Missing keys mean zero, zero results disappear,
and matched keys retain the left representative, as Runtime.Word does.
Ordinary map persistence, ordering and owned-key cleanup remain unchanged.

## Resolved Grill Log

Borrow ascending input views, merge in O(n+m), retain surviving keys once,
then build a balanced tree in O(n+m) with logarithmic recursion. Check
allocation sums/products and free staging buffers. Defined uint64_t bitwise
operations preserve every bit; no signed narrowing or insertion-loop fallback.
Direct calls and builtin values share exact checked signature admission and
operand snapshots, preserving left-to-right evaluation across frame methods.
Granular tree node/retain parts prevent unused helpers in callable entries.

Predicates, popcount/members, MultiMap and Buckets remain separate obligations.
[[Native Word Map Algebra Delivery]] records validation and review status.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Native Persistent Trees]]
