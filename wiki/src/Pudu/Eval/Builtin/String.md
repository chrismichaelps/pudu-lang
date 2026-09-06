---
type: module
path: "@root/src/Pudu/Eval/Builtin/String.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.9
tags: [module, medium, runtime]
aliases: [Eval Builtin String]
---

# Eval Builtin String

## Purpose

Implement built-in methods on text values, including scalar slicing, character lookup, linear substring scanning, case conversion, prefix/suffix testing, and run spans.

## Interface

```haskell
callStringMethod :: Span -> StringMethod -> Value -> [Value] -> Evaluator Value
indexOfText :: Text -> Text -> Integer
```

## Governance

- Text operations count Unicode scalar values, not bytes, matching developer expectations and indexing semantics.
- `drop` and `take` cost what they move, not the size of the whole text, enabling linear-time streaming parsing across large files.
- Negative indices and out-of-range bounds report `E7004` rather than silently clamping or wrapping.
- An empty needle in `indexOfText` returns index 0; non-matches return `-1` to match array index conventions.

## Linkage

- **Requires:** `Pudu.Eval.Bytes`, `Pudu.Eval.Env`, `Pudu.Eval.Value`, `Pudu.Source`, `Data.Text`.
- **Consumed by:** `Pudu.Eval.Builtin`.

## Negative Logic (Prohibited Paths)

- No higher-order callbacks or `Apply` parameter: text operations never invoke user functions.
- No locale-dependent transformations; Unicode case folding and scalar indexing are uniform across platforms.

## Grill Log

- **Q:** Why extract text methods into `Eval.Builtin.String`? **A:** String method dispatch and its localized helpers (`charAt`, `slice`, `spanLength`, `indexOfText`) comprise ~130 lines of pure string algorithms that do not depend on evaluator closures or host IO.
