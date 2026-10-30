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

- A range is walked from its own ends rather than turned into an array first. The list is lazy, so a
  loop that breaks early reads only as far as it got and `for i in 0..20_000_000` allocates nothing
  up front — residency is flat across two orders of magnitude of range length. An unbounded range has
  no last value and so is not iterable, which the ordinary refusal reports.

- A loop's body is a block and a block holds loops, so what this needs of the
  evaluator **arrives as a record**. Three things: a condition is an expression,
  a body is a block, and a sequence's `advance` is a closure the program
  supplied.
- **A type that writes `Sequence` is iterated by it; a sum falls back to the
  payload its matched variant carries only when nothing does.** [[Type Check Iteration]]
  decides the binder's type in exactly this order, and taking the payload first
  made the two disagree — a binder the checker called `Int` held a variant.
- Positional sums carry canonical owner identity independently of their short label.
  `receiverOwners` uses that owner directly. Ownerless host values and legacy
  named payloads retain the short-tag registry fallback until their separate audit.
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

- **Q:** May a short tag override a carried owner?
  **A:** No. Canonical identity selects the implementation directly; registry lookup
  remains only for legacy values without carried ownership. Same-named variants
  from different modules must never dispatch through one another's implementation.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Type Check Iteration]]

## Pure dependency-region kernel

Before ordinary while dispatch, attempt [[Eval Loop Kernel]]. Entirely
unsupported regions retain the existing loop unchanged. Both evaluators use the
same pure loop kernel for eligible scalar and MultiMap regions, including
closed parameter-only module functions whose complete bodies pass its proof.
Resolved Grill Log: preserve transfers and effect boundaries through whole-region
fallback; retain ordinary execution as the oracle for non-native library wrappers.

## Shared compile-time boundaries

[[Compile Time Limits]] supplies the existing depth/iteration constants to both
evaluation and derive residualization. Runtime loop policy and thresholds remain
unchanged. Resolved Grill Log: one phase-neutral declaration prevents nested
compiler expansion and ordinary constant evaluation from drifting apart.

## Positional sum owners (#761)

Owned positional sums dispatch only through the owner carried by the value. Legacy ownerless host values and named payloads retain their existing lookup path until the remaining #761 audit; a tag cannot override a carried owner.

Resolved Grill Log: identity comes from the declaration or native ABI, not a global short-tag registry. Keep labels, evaluation order, effects and wire bytes stable. See [[Positional Sum Owner Delivery]].
