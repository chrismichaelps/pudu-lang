---
type: module
path: "@root/src/Pudu/Type/Check/Prelude.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.9
tags: [module, shallow]
aliases: [Type Check Prelude]
---

# Type Check Prelude

## Purpose

The names a program has without declaring them: the constructors every program can write, and the signature of every effect the prelude provides.

## Interface

```haskell
declareBuiltinConstructors :: Checker ()
effectSignatures           :: [(Text, Scheme)]
```

### Governance

- **A table rather than a rule.** Nothing here decides anything; it states what the language already has.
- That is why it depends on nothing in checking and nothing in checking reaches back into it — which made this the one cut in the checker that needed no capability at all.
- Every effect answers with `Result[T, Str]` rather than failing, so a missing file is an outcome a caller handles rather than something that stops the program.
- Existing TCP/TLS effects retain their original signatures; separately named `Within` connect,
  send, receive, and TLS-close signatures carry the millisecond operation timeout consumed by the
  runtime boundary. `Std.Net` and `Std.Tls` own the typed public spelling.

### Linkage

- **Requires:** [[Type Env]], [[Type Value]].
- **Consumed by:** [[Type Check Method]].

## Grill Log

- **Q:** Replace the original network signatures with timeout parameters? **A:** No. _Rationale:_
  existing source must retain its original effect ABI; separately named `Within` effects carry the
  new argument. _Rejected:_ an arity-breaking replacement.

## Referenced by

[[src/Pudu/Type/_MOC]]

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
