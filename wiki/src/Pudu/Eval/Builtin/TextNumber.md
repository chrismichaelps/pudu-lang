---
type: module
path: "@root/src/Pudu/Eval/Builtin/TextNumber.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, text, numeric]
aliases: [Eval Builtin TextNumber]
---

# Eval Builtin TextNumber

## Purpose

Read the number a whole text spells, for the `Str` methods `toInt`, `toFloat`, and `toDecimal`.

## Interface

- `readWhole :: Text -> Maybe Integer` — optional `+`/`-`, one or more ASCII digits, within `Int64`.
- `readFloat :: Text -> Maybe Double` — optional sign, digits on at least one side of an optional
  point, optional `e`/`E` exponent of at most six digits; finite results only.
- `readDecimal :: Text -> Maybe Decimal` — `parseDecimalText` on text with no whitespace or `_`.

## Semantics

Every reader requires the whole text to be the number: no surrounding space, no separators, no
radix prefixes, no non-ASCII digits. The float is normalised to `d.d[e±n]` and converted by the
host's correctly rounded reader; `inf`, `nan`, and results past binary64 answer `Nothing`.

## Grill Log

- **Q:** Trim surrounding space? **A:** No. _Rationale:_ a reader that trims in one place and not
  another accepts `" 42"` inconsistently; callers write `.trim()` where they mean it.
- **Q:** Accept `inf`/`nan`? **A:** No. _Rationale:_ nobody types them as input, and admitting them
  lets a malformed form field become a value that poisons every later comparison.
- **Q:** Write the float reader in Pudu? **A:** No. _Rationale:_ correctly rounded decimal-to-binary
  conversion is subtle and slow in the evaluator; the host's is exact.
- **Q:** Why cap the exponent at six digits? **A:** Anything longer is already past binary64 in either
  direction; the cap keeps a hostile exponent from costing a large intermediate.

## Referenced by

[[Eval Builtin String]] · [[Uses Text To Number]]
