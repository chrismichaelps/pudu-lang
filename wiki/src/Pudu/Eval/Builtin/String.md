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
callStringMethodFast :: Span -> Text -> Text -> [Value] -> Maybe (Evaluator Value)
drop1Text :: Text -> Text
dropText :: Int -> Text -> Text
indexOfText :: Text -> Text -> Integer
```

## Governance

- Text operations count Unicode scalar values, not bytes, matching developer expectations and indexing semantics.
- `drop` and `take` cost what they move, not the size of the whole text, enabling linear-time streaming parsing across large files.
- `drop1Text` directly inspects the underlying UTF-8 byte array to advance 1 scalar in O(1) time without character stream decoding overhead.
- `callStringMethodFast` enables direct method dispatch for string methods without intermediate `StringMethodValue` closure allocation.
- Negative indices and out-of-range bounds report `E7004` rather than silently clamping or wrapping.
- An empty needle in `indexOfText` returns index 0; non-matches return `-1` to match array index conventions.

## Linkage

- **Requires:** `Pudu.Eval.Bytes`, `Pudu.Eval.Env`, `Pudu.Eval.Value`, `Pudu.Source`, `Data.Text`.
- **Consumed by:** `Pudu.Eval.Builtin`, `Pudu.Eval.Call`.

## Negative Logic (Prohibited Paths)

- No higher-order callbacks or `Apply` parameter: text operations never invoke user functions.
- No locale-dependent transformations; Unicode case folding and scalar indexing are uniform across platforms.

## Grill Log

- **Q:** Why extract text methods into `Eval.Builtin.String`? **A:** String method dispatch and its localized helpers (`charAt`, `slice`, `spanLength`, `indexOfText`) comprise ~130 lines of pure string algorithms that do not depend on evaluator closures or host IO.
- **Q:** Why provide low-level `drop1Text` and `callStringMethodFast`? **A:** Streaming text scanners and parsers repeatedly advance text by 1 scalar; decoding UTF-8 or allocating intermediate closures for each scalar introduces superlinear GC pressure on large in-memory buffers.
