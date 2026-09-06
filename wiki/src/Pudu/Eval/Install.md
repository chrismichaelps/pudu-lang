---
type: module
path: "@root/src/Pudu/Eval/Install.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.85
tags: [module, medium, runtime]
aliases: [Eval Install]
---

# Eval Install

## Purpose

Put a module's declarations into the environment before anything runs: functions, foreign
bindings, variant constructors, implementation methods, and then the constants that may reference
them.

## Interface

```haskell
type Evaluate = Located Expression -> Evaluator Value

loadDeclarations :: Evaluate -> [Located Declaration] -> Evaluator ()
targetNameOf     :: Located TypeSyntax -> Maybe Text
lastSegmentOf    :: NonEmpty Text -> Text
```

### Governance

- The wired-in sums record their variants' owners exactly as a declared sum does. Without it an implementation written for `Option` or `Result` is looked for under `Some` or `Err`, and is never found.
- **Order is the whole point.** Functions and variant constructors are installed before any constant
  runs, so mutual recursion and forward references work exactly as [[Name Resolution]] promised they
  would. A constant evaluated before its neighbours exist would make declaration order matter in a
  language whose resolution says it does not.
- An implementation's methods are installed under a key naming the type they implement for, and
  again under the trait, so a member access on a value and a trait-qualified call both find them.
- A trait member carrying a body is a default: an implementation that does not override it still
  has it, and `inheritedDefaults` is what puts it there.
- A variant is bound unqualified and under its type's name, so `Circle` and `Shape.Circle(3)` reach
  the same value.
- The `Evaluate` capability exists because a module constant's value is an expression, and
  evaluating one needs the environment this module is still building. One direction has to be an
  argument, and this is that direction.
- A foreign binding retains the block-local handle crossings, whether its result is owned, and
  whether it is the declared release for a handle. The evaluator therefore does not rediscover
  ownership from function names at call time.
- A foreign binding keeps its idiomatic local name as the environment key and the explicitly mapped
  native symbol, when present, as the dynamic-loader key. Release ownership is still related by
  local declaration names, so a foreign spelling never leaks into name resolution.
- An owned producer resolves its `by` name to the release declaration's exact native symbol while
  the block is installed. Runtime teardown therefore calls what the declaration mapped, not a local
  spelling or naming convention.

### Linkage

- **Requires:** [[Eval Value]], [[Eval Env]], [[Syntax Tree]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Install the built-in constructors, collect trait members into a table, install every declaration
against it, then evaluate each constant in declaration order.

## Negative Logic (Prohibited Paths)

- No evaluation of anything but a constant's initialiser, and that only through the capability.
- No installing a constant before the functions it may call.
- No typing decisions.

## Grill Log

- **Q:** Look up a release by local name during teardown? **A:** No; resolve its native symbol while
  installing the foreign block. _Rationale:_ `symbol "MemFree"` proves local and native names may
  differ, and cleanup must call the same declaration explicit release calls. _Rejected:_ guessing
  the exported symbol from the Pudu name.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Name Resolution]]

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

## Native sparse word enumeration

`WordMapMembersBuiltin` is installed under the name `wordMapMembers`. It is dispatched as a
pure primitive taking `Map[UInt64, UInt64]` and returning `Array[UInt64]`.

Resolved Grill Log: Register as a pure built-in alongside existing word-map operations. Emit
unpacked IDs directly as an ArrayValue. No tests or measurements run.

## Buffer and SwissTable installation

Binds the 12 primitive names in the initial evaluation environment:
`bufferAlloc`, `bufferReadU64`, `bufferWriteU64`, `bufferScanU64`, `bufferCopy`, `bufferSize`,
`swissTableEmpty`, `swissTableLookup`, `swissTableInsert`, `swissTableDelete`, `swissTableEntries`,
and `swissTableSize`. Each name maps to its corresponding `Builtin` constructor.

Resolved Grill Log: Install all 12 primitives as first-class builtin values available at top-level scope without dynamic handle allocation.


