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
escapeHtmlText :: Text -> Text
charAtFast :: Span -> Text -> Integer -> Evaluator Value
countPrefix :: (Char -> Bool) -> Text -> Int
characterMember :: Text -> Char -> Bool
```

## Governance

- Text operations count Unicode scalar values, not bytes, matching developer expectations and indexing semantics.
- `drop` and `take` cost what they move, not the size of the whole text, enabling linear-time streaming parsing across large files.
- `drop1Text` directly inspects the underlying UTF-8 byte array to advance 1 scalar in O(1) time without character stream decoding overhead.
- `callStringMethodFast` directly dispatches all 22 built-in string methods (`drop`, `isEmpty`, `charAt`, `take`, `contains`, `startsWith`, `endsWith`, `indexOf`, `spanOf`, `spanNotOf`, `slice`, `escapeHtml`, `trim`, `toUpper`, `toLower`, `replace`, `repeat`, `split`, `toBytes`, `chars`, `lines`, `reverse`) without intermediate `StringMethodValue` closure allocation or environment traversal.
- `charAtFast` reads a character at an index by dropping scalars and unpacking a single head via `Text.uncons` after verifying bounds against byte length, eliminating full-string scanning (`Text.length`).
- `escapeHtmlText` escapes HTML entities (`&`, `<`, `>`, `"`, `'`) using a lazy text builder fast path that skips unescaped text segments in chunks, avoiding repeated string substitutions.
- `countPrefix` counts contiguous matching characters in a single pass over `Text.uncons`, avoiding intermediate slice allocations.
- `characterMember` constructs a lookup `Set` for multi-character alphabets, avoiding repeated $O(K)$ linear searches across alphabet characters.
- String counts and repeat multipliers are bounded against `textBytes` and machine `Int` limits (`textCount`), preventing arithmetic overflow and out-of-memory panics.
- Negative indices and out-of-range bounds report `E7004` rather than silently clamping or wrapping.
- An empty needle in `indexOfText` returns index 0; non-matches return `-1` to match array index conventions.

## Linkage

- **Requires:** `Pudu.Eval.Bytes`, `Pudu.Eval.Env`, `Pudu.Eval.Value`, `Pudu.Source`, `Data.Text`, `Data.Text.Lazy.Builder`, `Data.Set`.
- **Consumed by:** `Pudu.Eval.Builtin`, `Pudu.Eval.Call`.

## Negative Logic (Prohibited Paths)

- No higher-order callbacks or `Apply` parameter: text operations never invoke user functions.
- No locale-dependent transformations; Unicode case folding and scalar indexing are uniform across platforms.
- No unbounded memory allocations in `repeat`; multiplier * byte length must fit in machine integer bounds.

## Grill Log

- **Q:** Why extract text methods into `Eval.Builtin.String`? **A:** String method dispatch and its localized helpers (`charAt`, `slice`, `spanLength`, `indexOfText`, `escapeHtmlText`) comprise pure string algorithms that do not depend on evaluator closures or host IO.
- **Q:** Why provide low-level `drop1Text` and `callStringMethodFast`? **A:** Streaming text scanners and parsers repeatedly advance text by 1 scalar; decoding UTF-8 or allocating intermediate closures for each scalar introduces superlinear GC pressure on large in-memory buffers. Direct dispatch for all 22 built-in methods avoids closure allocation across all string operations.
- **Q:** Why use `charAtFast` instead of `Text.index`? **A:** `Text.index` scans the entire text from start to finish and calls `Text.length` for bounds checking, which degrades character iteration into $O(N^2)$ time. `charAtFast` bounds-checks using `byteLength` and drops only the target prefix before `Text.uncons`.
- **Q:** Why use `escapeHtmlText` with `Builder` rather than repeated string replaces? **A:** Five sequential `.replace()` calls parse and reallocate intermediate text buffers five times. The builder scans in chunks and writes entities directly to a lazy buffer in a single pass.
- **Q:** Why use `textCount`? **A:** Converting an arbitrary-precision `Integer` from Pudu source directly to machine `Int` can overflow or cause out-of-range memory faults if unvalidated. Clamping against `textBytes` guarantees safe machine integer conversion.
