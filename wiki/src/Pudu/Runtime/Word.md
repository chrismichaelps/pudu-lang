---
type: module
path: "@root/src/Pudu/Runtime/Word.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance]
aliases: [Runtime Word Kernels]
---

# Runtime Word Kernels

## Purpose, interface and invariants

`countWords` accepts a fallible projection into Word64 and folds any Foldable container directly.
Each valid word uses Data.Bits.popCount with a strict Integer accumulator. Failure retains the
first projection error; subsequent payloads are not projected, although the container spine is
still traversed. No intermediate word collection, list or per-bit loop is constructed. INLINE
exposes the projection and fold at the consumer. Hardware instruction selection is GHC/target
controlled, not promised by this API. The module has no evaluator or frontend dependency.

## Grill Log

- **Q:** Count bits in Pudu callbacks? **A:** No; traverse the host container once and apply the
  native Word64 population count to each checked payload. This removes interpreted bit loops.
- **Q:** Claim an unboxed map or measured speedup? **A:** No; the map still stores boxed values.
  The change removes dispatch and staging, not the tree representation. No validation was run.

## Dependencies and consumers

[[Eval Word Map]] adapts [[Runtime Word Kernels]] for [[Std BitSet]] through [[Eval Builtin]].

## Referenced by

[[src/_MOC]] · [[Backend Representation Specialization]]

## Native word-map algebra

Four pure primitives `wordMapUnion`, `wordMapIntersection`, `wordMapDifference`, and
`wordMapSymmetricDifference` each take two Map[K, UInt64] values and return Map[K, UInt64].
Absent keys denote zero words; zero results are omitted. Shared keys retain the left key
representative. UInt64 payloads are validated in ascending key order, left input before right,
including entries the operation will discard. Invalid runtime values report E7001; wrong arity
reports E7003. Existing argument evaluation remains left to right. These names are installed,
typed and dispatched as pure primitives; Std.BitSet uses them directly.

The internal `WordOperation` enum selects `combineMaps`: tree-native mergeWithKey applies OR,
AND, AND-complement or XOR without interpreted callbacks or entry arrays. The evaluator validates both input maps first, then projects payloads during merging and
encodes directly into the final map. The input and result trees still hold boxed values; no
projected input tree or separately encoded output tree is constructed.

Resolved Grill Log: Validate all payloads before algebra so malformed values cannot hide in a
discarded branch. Drop all zero results, including unmatched zeros, for canonical sparse output.
No tests, builds, reviews or measurements run.

## Short-circuit word predicates

`wordMapIsSubsetOf` and `wordMapIsDisjointFrom` take two Map[K, UInt64] values and return Bool.
They consume `compareMaps` in [[Runtime Word Kernels]] with a fallible UInt64 projection. A lazy
ascending map fold visits left payloads and looks up corresponding right payloads; absent right
keys mean zero. Subset requires `left & complement right == 0`; disjointness requires
`left & right == 0`. Both return true for empty left input and stop at the first false block.
No entry array, projected map or result map is constructed. Worst-case work is O(n log(m+1)),
where n and m count left and right blocks. Tree nodes and payloads remain boxed.

Only visited payloads are validated, left word before matching right word. Unmatched right
payloads and blocks after the first counterexample are not inspected. This preserves STD's
short-circuit traversal; unlike algebra it is not a full-map validation operation. A visited
invalid UInt64 kind/range or non-map argument reports E7001; wrong arity reports E7003.
Registration includes names, types, installation and pure dispatch. STD delegates directly.

Resolved Grill Log: Do not swap inputs for disjointness even if the right map is smaller: the
left-first visitation and failure order are explicit. Keep the right fold lazy in its remainder
so a counterexample does not force later lookups. No tests, builds, reviews or measurements run.

## Direct payload-tree algebra

`combineMapsWith` generalizes tree algebra with total `a -> Word64` and `Word64 -> a`
representation adapters. `combineMaps` remains the identity-adapter specialization. Matched
words combine and encode directly into the result; retained unmatched words are projected,
zero-filtered and encoded with mapMaybe. No projected input trees or separate output encoding
tree are needed. Existing map key representatives and sparse zero elimination remain intact.

The evaluator performs ascending, left-before-right payload validation using traverse_ before
calling the total projection kernel. Its local word extractor is used only after that successful
pass over the same immutable trees; a non-integer fallback is unreachable through this entry
point. Full-input error detection remains unchanged. Surviving payloads are read again during
merging, trading a second scalar read for removing three temporary map transformations. No
unsafe host operations, IO, hidden state or new surface signatures are introduced.

Resolved Grill Log: Preserve full validation rather than letting discarded keys conceal malformed
values. Do not cache validated words in another tree: the purpose is to reduce allocation. Native
Word64 callers retain the original combineMaps API. No measured speedup or validation is claimed.

## Native sparse word enumeration

`unpackWords` accepts a base 64-bit ID and a word, extracting set bit positions using
`countTrailingZeros` and bit clearing `w .&. (w - 1)`. Output IDs combine `base .|. tz` in
ascending order and prepend onto the tail list. When the word is 0, it returns the tail
directly. No per-bit shifting loop is performed.

Resolved Grill Log: Use hardware trailing-zero counts and single-instruction bit clearing
rather than stepping through 64 shifts. Ascending order is preserved by folding keys with
foldrWithKey and prepending bits. No tests or measurements run.

