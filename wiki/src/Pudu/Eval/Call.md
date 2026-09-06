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

### Linkage

- **Requires:** [[Eval Env]], [[Eval Value]], [[Eval Builtin]], [[Eval Operator]],
  [[Eval Dispatch]].
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
AND, AND-complement or XOR without interpreted callbacks or entry arrays. The evaluator first
projects each map to checked Word64 payloads and maps the result back to UInt64 values. These
intermediate native-word trees are an explicit allocation tradeoff, not an unboxed-storage claim.

Resolved Grill Log: Validate all payloads before algebra so malformed values cannot hide in a
discarded branch. Drop all zero results, including unmatched zeros, for canonical sparse output.
No tests, builds, reviews or measurements run.
