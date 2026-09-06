---
type: module
path: "@root/src/Pudu/Eval/Builtin.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 4.0
interface_stability: 0.8
tags: [module, medium, runtime]
aliases: [Eval Builtin]
---

# Eval Builtin

## Purpose

Implement the values [[Semantic Prelude]] wires in: the effects, the built-in methods on arrays,
text, maps, sets, and characters, and the conversions nothing in the language can express.

## Interface

```haskell
type Apply = Span -> Value -> [Value] -> Evaluator Value

callArrayMethod  :: Apply -> Span -> ArrayMethod -> Value -> [Value] -> Evaluator Value
callStringMethod :: Span -> StringMethod -> Value -> [Value] -> Evaluator Value
callMapMethod, callSetMethod, callCharMethod :: Span -> ... -> Evaluator Value
callEffect       :: Span -> Builtin -> [Value] -> Evaluator Value
callDecimal      :: Span -> Builtin -> [Value] -> Evaluator Value
callShow, callDisplay, callPanic, callMapOf, callSetOf, callCharFromCode,
callConvertInteger :: Span -> ... -> Evaluator Value
effectBuiltins   :: [Builtin]
isDecimalBuiltin :: Builtin -> Bool
```

### Governance

- **Only `callArrayMethod` takes the `Apply` capability**, because only it calls back into a value
  the caller supplied: `map`, `filter`, and `reduce` invoke their argument, and dispatch needs the
  method to answer a call. That is a genuine cycle and the capability is how it is expressed. The
  other method families take no capability because they never call back, and giving them one would
  have claimed a dependency that does not exist.
- Every effect answers with `Result[T, Str]` rather than failing. The language has no exceptions, so
  a missing file is an outcome a caller handles, and the failure carries what the operating system
  said rather than a message this compiler invented.
- Effects are refused while a constant is folded. A `const` initialiser runs inside the compiler, so
  reading a file there would make the compiled output depend on the machine that compiled it.
- `show` quotes text and `display` does not. A reader inspecting a value needs `"1"` never to be
  mistaken for the number; a message being built wants the string's own content. Everything that is
  not text or a character renders identically either way.
- `effectBuiltins` is one list so the evaluator and the checker cannot disagree about which names
  exist, and adding an effect is one edit rather than three.

- **`drop` and `take` cost what they move, not what the text holds.** Indexing walks from the start, so a reader that keeps a position into the whole text pays again for every character it has already passed and a scan costs the square of the input. These two are what let a reader carry the text it has not read yet, which is the shape every parser over a file needs.

### Linkage

- **Requires:** [[Eval Value]], [[Eval Env]], [[Eval Array]], [[Eval Keyed]], [[Eval Io]],
  [[Eval Clock]], [[Eval Order]], [[Decimal Literal]], [[Integer Literal]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Dispatch on the built-in tag and the argument shapes, answering with a value or aborting with an
`E7xxx` diagnostic. Higher-order array methods call the supplied `Apply`.

## Negative Logic (Prohibited Paths)

- No typing. The checker has already decided what these receive; re-deciding here would put one rule
  in two phases.
- No importing [[Evaluator]]. The `Apply` capability is the path back.
- No host exceptions. Every failure is a diagnostic.

## Grill Log

- **Q:** Why does only one method family take the capability? **A:** Because only one has the cycle.
  _Rationale:_ threading `Apply` through the map, set, char, and text families made four signatures
  claim a dependency none of them has, and GHC said so immediately. _Rejected:_ a uniform signature
  for symmetry.
- **Q:** Why are effects blocked at fold time rather than refused statically? **A:** They are not,
  any more — see [[ADR-0009]] for the proposal that moves the check into the type. Today the gate is
  here because effects have no static vocabulary to check against.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Semantic Prelude]]

## Sequence-native higher-order operations

Array map traverses the sequence directly and returns that result sequence. Filter folds the
sequence into a persistent output sequence, appending only accepted values. Reduce folds the
sequence without list conversion. Callbacks remain left-to-right, once per visited element;
a failed callback prevents later invocations. Receiver and arity diagnostics are unchanged.

### Resolved Grill Log
- **Q:** Flatten every array before invoking callbacks? **A:** No; native Traversable/Foldable sequence operations preserve order without an intermediate input list.
- **Q:** Parallelize callbacks while removing staging? **A:** No; evaluation order and effects remain observable and sequential.

## Direct enumeration continuation

Runtime collection enumeration builds output sequences directly with ascending strict folds.
Map values no longer construct key/value pairs merely to discard keys. Map keys, entries, set
members and indexed-bucket enumeration retain their previous ordering and value representation.
Legacy list-returning keyed helpers remain for callers that require lists.

### Resolved Grill Log
- **Q:** Allocate intermediate key/value pairs to return values? **A:** No; traverse payloads directly.
- **Q:** Change enumeration order for a faster layout? **A:** No; the native ascending fold preserves the existing order.

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

`WordMapMembersBuiltin` wires `wordMapMembers(Map[UInt64, UInt64]) -> Array[UInt64]`. It unpacks
set bit indices from word blocks in ascending order. Non-map or invalid UInt64 keys/payloads
report E7001; wrong arity reports E7003.

Resolved Grill Log: Register as a pure built-in alongside existing word-map operations. Emit
unpacked IDs directly as an ArrayValue. No tests or measurements run.

