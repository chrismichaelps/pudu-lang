---
type: module
path: "@root/src/Pudu/Eval/Loop.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 4.0
interface_stability: 0.8
tags: [module, medium, runtime]
aliases: [Eval Loop]
---

# Eval Loop

## Purpose

Run the looping forms, and iterate a value by the protocol its type implements.

## Interface

```haskell
data LoopNeeds = LoopNeeds
  { loopEvaluate :: Located Expression -> Evaluator Value
  , loopBlock    :: Located Block -> Evaluator Value
  , loopClosure  :: Closure -> [Value] -> Maybe Span -> Evaluator Value
  }

evaluateWhile, evaluateLoop, evaluateFor :: LoopNeeds -> Span -> ...
sequenceMethods :: Value -> Evaluator (Maybe (Value, Value))
receiverOwners  :: Value -> Evaluator [Text]
```

### Governance

- A loop's body is a block and a block holds loops, so what this needs of the
  evaluator **arrives as a record**. Three things: a condition is an expression,
  a body is a block, and a sequence's `advance` is a closure the program
  supplied.
- **A type that writes `Sequence` is iterated by it; a sum falls back to the
  payload its matched variant carries only when nothing does.** [[Type Check Iteration]]
  decides the binder's type in exactly this order, and taking the payload first
  made the two disagree — a binder the checker called `Int` held a variant.
- **A value names the variant it is, not the type that declares it.** Asking
  whether a `Cons` is a sequence therefore asks what `Cons` belongs to, which is
  why `receiverOwners` answers with the variant's own name and then its owner.
  The variant comes first, because a record type is its own owner and must not
  be looked past.
- **The compiler must terminate; a program need not.** A loop is bounded only
  while effects are refused, which is exactly when a `const` is being folded.
  A fixed step count applied to both is not a safety property — an input of any
  size needs more steps than any constant could allow.
- A break or a continue belongs to this loop when it named this loop's label,
  and is passed outward otherwise.

### Linkage

- **Requires:** [[Eval Env]], [[Eval Value]], [[Eval Match]], [[Eval Operator]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Walk the body, read what the outcome means for this loop, and either continue,
stop, or pass the transfer outward. A sequence threads the state each `advance`
answers with.

## Negative Logic (Prohibited Paths)

- No importing [[Evaluator]] — the record is the path back.
- No typing. What a binder holds was decided by [[Type Check Iteration]]; deciding
  it again here would put one rule in two phases.

## Grill Log

- **Q:** Why does `receiverOwners` answer with two names rather than one?
  **A:** Because a value has lost its type. _Rationale:_ the checker holds
  `List` and looks up `List.begin` directly; the evaluator holds a `Cons` and
  nothing in the value says which sum it came from, so the declaration leaves
  that behind at install time and both names are tried. _Rejected:_ tagging
  every value with its owning type, which costs every value for a lookup few
  need.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Type Check Iteration]]
