---
type: module
path: "@root/src/Pudu/Eval/Builtin/Array.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.9
tags: [module, medium, runtime]
aliases: [Eval Builtin Array]
---

# Eval Builtin Array

## Purpose

Implement built-in method dispatch on array values, including element access, mutations, reversals, slices, joining, and higher-order callbacks (`map`, `filter`, `reduce`).

## Interface

```haskell
type Apply = Span -> Value -> [Value] -> Evaluator Value

callArrayMethod :: Apply -> Span -> ArrayMethod -> Value -> [Value] -> Evaluator Value
```

## Governance

- `callArrayMethod` takes the `Apply` capability because only it invokes caller-supplied functions (`map`, `filter`, and `reduce`).
- Higher-order callbacks use `acceptByFunction` to evaluate boolean predicates strictly before mutating or appending to the accumulator.
- Non-array receivers report `E7001` ("not an array").
- Out-of-bounds index operations report `E7004` ("index out of range").
- Arity mismatches report `E7003` with actionable guidance.

## Linkage

- **Requires:** `Pudu.Eval.Array`, `Pudu.Eval.Env`, `Pudu.Eval.Value`, `Pudu.Source`.
- **Consumed by:** `Pudu.Eval.Builtin`.

## Negative Logic (Prohibited Paths)

- No string or collection method dispatch here; those belong to `Eval.Builtin.String` and `Eval.Builtin.Collection`.
- No operating system effect execution; effects belong to `Eval.Effect`.

## Grill Log

- **Q:** Why extract array methods into a dedicated submodule? **A:** `callArrayMethod` carries the only `Apply` capability parameter and represents ~100 lines of self-contained higher-order dispatch logic, isolating evaluator callback dependencies from pure primitive operations.
