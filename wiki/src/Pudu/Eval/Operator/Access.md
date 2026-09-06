---
type: module
path: "@root/src/Pudu/Eval/Operator/Access.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.9
tags: [module, medium]
aliases: [Eval Operator Access]
---

# Eval Operator Access

## Purpose

Own indexing into collections and strings, field extraction, method dispatch table lookup, nominal runtime type name extraction, and `?` operator unwinding.

## Interface

```haskell
readIndex :: Span -> Value -> Value -> Evaluator Value
readMember :: Span -> Value -> Text -> Evaluator Value
nominalNameOf :: Value -> Maybe Text
builtinMethodNamesFor :: Text -> [Text]
unwrapTry :: Span -> Value -> Evaluator Value
```

## Governance

- `readIndex` handles tuples, strings, and arrays with strict non-negative bounds checking, raising `E7004` on out-of-range indices.
- `readMember` searches records and nominal sums before falling back to built-in method tables (`Array`, `Str`, `Map`, `Set`, `Bytes`, `Buckets`, `Char`).
- `unwrapTry` returns the inner value for `Ok` and `Some`, or unwinds with `ReturnUnwind` for `Err` and `None`.
- `builtinMethodNamesFor` provides IDE/REPL autocompletion by reading from the exact same method tables used during evaluation dispatch.

## Linkage

- **Requires:** `Pudu.Eval.Bytes`, `Pudu.Eval.Env`, `Pudu.Eval.HashMap`, `Pudu.Eval.Value`, `Pudu.Source`.
- **Consumed by:** `Pudu.Eval.Operator`.

## Negative Logic (Prohibited Paths)

- No binary arithmetic or comparisons; those belong to `Eval.Operator`.
- No host exceptions; all indexing and member access failures raise `E7xxx` diagnostics.

## Grill Log

- **Q:** Why extract access and method lookup into `Eval.Operator.Access`? **A:** `readIndex`, `readMember`, `unwrapTry`, and the built-in method lookup tables form a cohesive access and inspection boundary (~240 lines) distinct from arithmetic and comparison operators, bringing `Eval.Operator` well below the 500-line limit.
