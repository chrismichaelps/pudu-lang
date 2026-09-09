---
type: module
path: "@root/src/Pudu/Eval/Call.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.65
depth_status: DEEP
coupling: 5.0
interface_stability: 0.75
tags: [module, deep, runtime]
aliases: [Eval Call]
---

# Eval Call

## Purpose

Call something, reach a name through a path, and join the tasks a scope owns.

## Interface

```haskell
data CallNeeds = CallNeeds
  { callEvaluate :: Located Expression -> Evaluator Value
  , callBlock    :: Located Block -> Evaluator Value
  }

evaluateCall   :: CallNeeds -> Span -> Located Expression -> [Located Expression] -> Evaluator Value
callClosure    :: CallNeeds -> Closure -> [Value] -> Maybe Span -> Evaluator Value
awaitTask      :: CallNeeds -> Span -> Value -> Evaluator Value
evaluateScope  :: CallNeeds -> Span -> Located Block -> Evaluator Value
readPath       :: CallNeeds -> ...
```

### Governance

- A call's arguments are expressions and an expression may be a call, so **what
  this needs of the evaluator arrives as a record**: an argument is an
  expression, a function's body is a block.
- **A path is read longest-binding-first.** `a.b.c` may be a module member, a
  field of a field, or a method on a value, and the longest name that actually
  binds is the one the reader meant — trying shortest-first would find a
  variable `a` and then fail on `.b` for a module that was in scope all along.
- **A method is found under the variant's own name and then under the type that
  declares it.** A value names the variant it is, and an implementation is
  written for the sum; without the second lookup no trait method worked on any
  sum type at all.
- A scope joins the children it started, in the order they started, before it
  yields. Deterministic order is what makes failure selection predictable rather
  than a race.
- Type arguments written at a call are not erased before it. Types have no
  run-time form, but the syntax the reader wrote is still here and names which
  instantiation was meant.
- Built-in string methods on `StrValue` receivers are fast-dispatched directly in
  `evaluateCall` via `callStringMethodFast`, bypassing `receiverOwners` queries and
  avoiding intermediate `StringMethodValue` heap closure allocations.

### Linkage

- **Requires:** [[Eval Env]], [[Eval Value]], [[Eval Builtin]], [[Eval Operator]],
  [[Eval Dispatch]], [[Eval Call Path]].
- **Consumed by:** [[Evaluator]], which ties the record, and through it
  [[Eval Program]] and [[Eval Loop]].

## Algorithm

Resolve the callee, evaluate the arguments left to right, then dispatch on what
the callee turned out to be — a closure, a builtin, a method value, or a
constructor.

## Negative Logic (Prohibited Paths)

- No importing [[Evaluator]] — the record is the path back.
- No typing. What a call means was decided by [[Type Check Call]]; deciding it
  again here would put one rule in two phases.

## Grill Log

- **Q:** Why do `callClosure`, `awaitTask`, and `scopeTo` also exist in
  [[Evaluator]]? **A:** Because a caller that only wants to run something should
  not have to know there is a record. _Rationale:_ [[Eval Program]] and the loop
  forms reach these, and threading the record to them would spread a detail of
  this module's construction across two more. _Rejected:_ exporting only the
  record-taking forms.
- **Q:** Why extract path reading and qualified callee dispatch to `Pudu.Eval.Call.Path`?
  **A:** To satisfy file length contracts (< 500 lines) and separate AST identifier/member chain traversal
  from runtime function application and task/scope evaluation. _Rationale:_ path resolution is a self-contained
  read query on the environment with no dependency on closures or task execution.
- **Q:** Why fast-path `MemberExpression` on `StrValue` in `evaluateCall`?
  **A:** Repeated text method calls in tight loops (such as text scanning and tokenization) incurred significant heap allocation from intermediate `StringMethodValue` closures and redundant environment trait queries, leading to GC-induced superlinear scaling pauses.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Eval Program]] · [[Eval Loop]]

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

## Native word-map member enumeration

`wordMapMembers[K](Map[K, UInt64]) -> Array[UInt64]` is a pure wired-in primitive consumed by
[[Std BitSet]]. It unpacks bits from sparse 64-bit blocks into an ascending array of member IDs,
dispatching via pure builtin dispatch without effect capabilities.

Resolved Grill Log: Include WordMapMembersBuiltin in `isHashingBuiltin` so it dispatches through
pure primitive dispatch rather than falling through to effect dispatch with E7012.

## Buffer and SwissTable call dispatch

Include `BufferAllocBuiltin`, `BufferReadU64Builtin`, `BufferWriteU64Builtin`, `BufferScanU64Builtin`,
`BufferCopyBuiltin`, `BufferSizeBuiltin`, `SwissTableEmptyBuiltin`, `SwissTableLookupBuiltin`,
`SwissTableInsertBuiltin`, `SwissTableDeleteBuiltin`, `SwissTableEntriesBuiltin`, and
`SwissTableSizeBuiltin` in `isHashingBuiltin` so they are routed through pure primitive dispatch.

Resolved Grill Log: Route buffer and flat map operations through the pure builtin dispatcher
before effect handling to preserve compiler constant-folding and effect isolation.

## Low-level buffer extensions and vectorized column dispatch

Include `BufferReadI64Builtin`, `BufferWriteI64Builtin`, `BufferReadF64Builtin`, `BufferWriteF64Builtin`,
`BufferReadU32Builtin`, `BufferWriteU32Builtin`, `BufferFillBuiltin`, `BufferCompareBuiltin`,
`ColumnSumU64Builtin`, `ColumnMinU64Builtin`, `ColumnMaxU64Builtin`, `ColumnFilterGtU64Builtin`,
`ColumnProjectU64Builtin`, `ColumnSumF64Builtin`, `ColumnMinF64Builtin`, `ColumnMaxF64Builtin`,
`ColumnFilterGtF64Builtin`, `ColumnFilterLtF64Builtin`, `ColumnProjectF64Builtin`, `ColumnAddF64Builtin`,
`ColumnBitmapAndBuiltin`, `ColumnBitmapOrBuiltin`, `ColumnBitmapNotBuiltin`, `ColumnBitmapCountBuiltin`,
`ColumnSortIndicesU64Builtin`, `ColumnSortIndicesF64Builtin`, `ColumnBinarySearchU64Builtin`,
`ColumnBinarySearchF64Builtin`, `ColumnGatherU64Builtin`, and `ColumnGatherF64Builtin`
in `isBuiltinImmediate` so they evaluate immediately without task scheduling or effect handler interception.

### Resolved Grill Log
- **Q:** Route vectorized columnar reductions through IO effects? **A:** No; column operations are pure mathematical and projection transformations operating deterministically on unboxed memory.
- **Q:** Route bitmap boolean algebra through immediate evaluation? **A:** Yes; bitmap bitwise operations are pure register bit operations without runtime side-effects.
- **Q:** Are sorting and binary search operations immediate builtins? **A:** Yes; permutation index generation and binary search lookups operate on deterministic unboxed memory without external capabilities or thread yielding.




