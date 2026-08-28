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
