---
type: module
path: "@root/lib/Std/BitSet.pudu"
fidelity: Active
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, performance]
aliases: [Std BitSet]
---

# Std BitSet

## Purpose and interface

A persistent sparse set of UInt64 IDs for row selections, compiler facts, permissions and graph
visitation. Each ordered map entry holds 64 membership bits. Empty blocks are omitted. `empty`,
`singleton`, `fromArray`, `insert`, `remove`, `contains`, `isEmpty`, `size`, and `toArray` provide the
collection interface. `union`, `intersection`, `difference`, `symmetricDifference`, `isSubsetOf`,
and `isDisjointFrom` operate on blocks without constructing arrays of individual members.
`fromBlocks` imports ordered-map storage with validation; `blocks` exposes a persistent snapshot.

## Representation and failure contract

`BitSet` is a public record with `words: Map[UInt64, UInt64]`, not an opaque resource. Block keys
must be at most 2^58-1, values must be nonzero. Use constructors or `fromBlocks` for external input;
manual records must maintain the same invariant. `fromBlocks` rejects the first oversized block
key with `Err(key)` and removes zero words. Every UInt64 ID is accepted, including its maximum.
The block key is `id >> 6`, and the mask is `1u64 << (id & 63u64)` after explicit conversion of
the low six bits to Int. Shifts are always within 0..63. Enumeration is ascending. `size` returns
UInt128 so even the mathematical full UInt64 domain has a representable cardinality. Enumeration
still requires memory proportional to the result and is intended for materializable sets.

## Algorithm and backend integration

Membership and point edits cost O(log b) map operations for b occupied blocks. Algebra calls
[[Runtime Word Kernels]] through checked pure primitives, combining host trees without Pudu entry
arrays or per-word interpreter calls. Subset and disjointness use native host-map scans without projected maps or entry arrays,
short-circuiting at the first disproving block. Cardinality calls `wordMapPopCount`, which folds map payloads directly with native Word64
population counts through [[Runtime Word Kernels]], avoiding entry arrays and interpreted bit loops. No FFI, IO, global mutation, unchecked memory or
new surface syntax is introduced. The evaluator still boxes words and stores tree nodes: this is
word-packed membership, not a contiguous unboxed bitmap or a claim of C/C++ throughput.

## Grill Log

- **Q:** Allocate storage up to the highest ID? **A:** No. Sparse blocks avoid enormous empty
  allocations for isolated large IDs; dense contiguous storage remains a separate future kernel.
- **Q:** How are invalid shifts and size overflow avoided? **A:** Mask shift counts to six bits
  and count in UInt128. No input ID is rejected or silently narrowed.
- **Q:** Expose complement without a universe? **A:** No. A universe-free complement would create
  an impractical full-domain set. Difference expresses bounded exclusion explicitly.
- **Q:** Are public records automatically valid? **A:** No. Document the invariant and provide
  validated import; ordinary record construction is not an opaque representation guarantee.

## Dependencies and consumers

Uses Core map, array, integer and Option/Result primitives. Intended for explicitly imported
compiler dataflow, database row-ID sets and application integer membership. Native bitwise and
shift paths are supplied by [[Integer Literal]] and map construction by [[Runtime Collection Kernels]].
Implementation is unvalidated at user direction; no performance measurements are available.

## Referenced by

[[src/Std/_MOC]] · [[Backend Representation Specialization]]

## Word-map cardinality kernel

`wordMapPopCount[K](Map[K, UInt64]) -> UInt128` is a pure wired-in reduction consumed by
[[Std BitSet]]. It counts payload bits independently of keys, including zero payloads, and avoids
entry-array materialization. The runtime checks UInt64 kind/range before conversion and reports
E7001 for invalid payloads or receiver, E7003 for wrong arity. Registration covers semantic names,
type signatures, installation, builtin naming and pure dispatch. No IO or FFI capability is required.

Resolved Grill Log: Use an explicit primitive rather than recognize a library function by name,
so shadowing and ordinary calls retain their meaning. Result width is UInt128; an Int-sized host
map cannot contain enough 64-bit words to overflow it. This remains unvalidated.

## Native word-map algebra

Four pure primitives `wordMapUnion`, `wordMapIntersection`, `wordMapDifference`, and
`wordMapSymmetricDifference` each take two Map[K, UInt64] values and return Map[K, UInt64].
Absent keys denote zero words; zero results are omitted. Shared keys retain the left key
representative. UInt64 payloads are validated in ascending key order, left input before right,
including entries the operation will discard. Invalid runtime values report E7001; wrong arity
reports E7003. Existing argument evaluation remains left to right. These names are installed,
typed and dispatched as pure primitives; Std.BitSet uses them directly.

The internal `WordOperation` enum selects `combineMaps`: tree-native mergeWithKey applies OR,
AND, AND-complement or XOR without interpreted callbacks or entry arrays. The evaluator first
projects each map to checked Word64 payloads and maps the result back to UInt64 values. These
intermediate native-word trees are an explicit allocation tradeoff, not an unboxed-storage claim.

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
