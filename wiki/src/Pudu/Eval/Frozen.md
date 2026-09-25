---
type: module
path: "@root/src/Pudu/Eval/Frozen.hs"
fidelity: Active
domain: "[[Evaluator]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium, performance]
aliases: [Eval Frozen]
---

# Eval Frozen

## Purpose

A constant's value when it is plain data, so the value folding computed can be bound when the
program links — and stored with a module's checked product — instead of evaluating its initializer
again.

## Interface

```haskell
newtype Frozen                      -- Eq, Show; Persist
freeze :: Value -> Maybe Frozen
thaw :: Frozen -> Value
```

## Governance

- **Only plain data freezes:** integers of every kind, floats, decimals, text, bytes, buckets,
  ranges, characters, booleans, null, unit, and tuples, arrays, maps, sets, records, and variants
  made only of those. A function, task, method, builtin, or anything foreign carries an environment
  or a resource of the evaluation that made it and never freezes; such a constant is evaluated at
  link time as before.
- **Folding's value is linking's value.** Folding evaluates a module alone with effects denied, and a
  constant reaching outside its module fails to fold and does not compile, so a constant that
  compiles is fixed by its own module.
- The stored form keeps every integer's kind, a float's width and exact bits, and a decimal's
  coefficient and scale.

## Linkage

- **Requires:** [[Eval Value]], [[Cache Persist]], [[Integer Literal]], [[Float Literal]],
  [[Decimal Literal]].
- **Consumed by:** [[Eval Program]], [[Compiler Pipeline]], [[Compiler Cache]], [[Compiler Program]].

## Negative Logic (Prohibited Paths)

- No environments, closures, resource stores, cells, native pointers, or runtime tokens.

## Grill Log

- **Q:** Reuse the compile-time environment? **A:** No; only immutable data leaves the fold.
  _Rejected:_ sharing an `Env` or resources between compile and run.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Program]] · [[Compiler Cache]]
