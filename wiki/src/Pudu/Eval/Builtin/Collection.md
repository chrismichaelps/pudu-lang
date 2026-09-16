---
type: module
path: "@root/src/Pudu/Eval/Builtin/Collection.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.9
tags: [module, medium, runtime]
aliases: [Eval Builtin Collection]
---

# Eval Builtin Collection

## Purpose

Implement constructor and method dispatch for ordered maps and sets, enforcing value comparability and structural immutability.

## Interface

```haskell
callMapOf :: Span -> [Value] -> Evaluator Value
callSetOf :: Span -> [Value] -> Evaluator Value
callMapMethod :: Span -> MapMethod -> Value -> [Value] -> Evaluator Value
callSetMethod :: Span -> SetMethod -> Value -> [Value] -> Evaluator Value
```

## Governance

- All map keys and set members must satisfy `comparableValue`. Non-orderable values (e.g. functions) report `E7008`.
- Set and map methods are pure and return newly constructed immutable collections; they never mutate the receiver.
- Lookups that miss return `Option::None` (`VariantValue "None" []`); found entries return `Option::Some(v)`.

## Linkage

- **Requires:** `Pudu.Eval.Env`, `Pudu.Eval.Keyed`, `Pudu.Eval.Order`, `Pudu.Eval.Value`, `Pudu.Source`.
- **Consumed by:** `Pudu.Eval.Builtin`.

## Negative Logic (Prohibited Paths)

- No fallback to insertion order for uncomparable values: map equality and hashing must be deterministic.
- No direct SwissTable or WordMap calls here; those belong to hardware-specialized runtime modules.

## Grill Log

- **Q:** Why extract collections separately from primitives? **A:** Map and set constructor/method dispatch form a cohesive subsystem (~90 lines) governed by ordered key invariants and option-wrapped return semantics.
