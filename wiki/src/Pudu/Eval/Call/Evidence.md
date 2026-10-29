---
type: module
path: "@root/src/Pudu/Eval/Call/Evidence.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime]
aliases: [Eval Call Evidence]
---

# Eval Call Evidence

## Purpose and interface

Run the implementation the checker's [[Syntax Tree]] trait evidence names.

```haskell
evidentMethod :: TraitEvidence -> Value -> Text -> Evaluator (Maybe Closure)
evidentCallee :: TraitEvidence -> Located Expression -> [Value] -> Evaluator (Maybe Value)
```

`evidentMethod` answers a receiver call. When the evidence names a parameter bound in the current
frame to a witness `TypeWitnessValue owner arguments`, it takes `<Trait>.<owner>.<member>` and binds
the implementation's leading parameters from the witness arguments; otherwise it tries the
receiver's run-time owners under the same canonical trait. The receiver is attached as `self`.

`evidentCallee` answers `T.member(...)` through the witness bound to `T` when `T` is the
evidence's parameter, and `Trait.member(receiver)` or `Module.Trait.member(receiver)` when the
path ends in the evidenced trait's name, through the receiver's witness or owner. Any other head
(`POINT.distance(other)` on an uppercase constant) is a receiver call and answers `Nothing`.

## Invariants and negative logic

- Only canonical keys are read here; a miss answers `Nothing` and the caller keeps its existing
  dispatch, so evidence never makes a previously running call fail.
- A witness binds the implementation's parameters positionally, the order a static selection
  lists them ([[Eval Call Path]] `selectTypes`). An implementation whose target arguments are not
  its parameters in declaration order is out of scope, as it already is for static selection.
- No typing decisions, no lending, and no argument evaluation.

## Grill Log

- **Q:** Read the element type off the run-time array? **A:** No; an empty array has none, and an
  array of arrays has only the outer owner. The caller's selected witness is the only complete
  answer. _Rejected:_ inferring parameters from values.
- **Q:** Prefer the witness or the receiver's owner? **A:** The witness: it is the type the checker
  proved, and it carries the arguments. The owner is the fallback when no witness was selected.
- **Q:** Treat any unbound uppercase head as a qualifier? **A:** No; a constant receiver would
  dispatch on its first argument. The head must be the evidence's parameter or name its trait.
- **Q:** Put this in `Pudu.Eval.Call`? **A:** No; that module is at the 500-line limit, and the
  evidence rule is one decision with two entry points.

## Linkage

Requires [[Eval Env]], [[Eval Value]], [[Eval Loop]], [[Eval Call Path]], [[Syntax Tree]].
Consumed by [[Eval Call]].

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Call]] · [[Trait Evidence Delivery]]
