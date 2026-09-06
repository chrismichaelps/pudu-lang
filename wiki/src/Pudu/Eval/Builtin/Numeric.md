---
type: module
path: "@root/src/Pudu/Eval/Builtin/Numeric.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.9
tags: [module, medium, runtime]
aliases: [Eval Builtin Numeric]
---

# Eval Builtin Numeric

## Purpose

Implement decimal primitives, numeric conversions across integer bit-width boundaries, and Unicode scalar character conversions.

## Interface

```haskell
isDecimalBuiltin :: Builtin -> Bool
callDecimal :: Span -> Builtin -> [Value] -> Evaluator Value
callConvertInteger :: Span -> [Text] -> [Value] -> Evaluator Value
callCharFromCode :: Span -> [Value] -> Evaluator Value
callCharMethod :: Span -> CharMethod -> Value -> [Value] -> Evaluator Value
```

## Governance

- Decimal operations enforce precision and rounding mode codes (`Std.Decimal.Rounding`). Half-even rounding is the default unbiased mode.
- Integer boundary conversions (`convertInteger[T]`) return `Option::None` if the target width cannot represent the value without overflow or truncation.
- Unicode character decoding rejects surrogate pairs (0xD800–0xDFFF) and code points exceeding 0x10FFFF, returning `Option::None`.

## Linkage

- **Requires:** `Pudu.DecimalLiteral`, `Pudu.FloatLiteral`, `Pudu.IntegerLiteral`, `Pudu.Eval.Env`, `Pudu.Eval.Value`, `Pudu.Source`.
- **Consumed by:** `Pudu.Eval.Builtin`.

## Negative Logic (Prohibited Paths)

- No silent truncation or wrapping on integer conversions: bit masks must be explicitly supplied by the caller if low-bit truncation is intended.
- No float parsing inside decimal operations; decimal parsing strictly preserves decimal digits.

## Grill Log

- **Q:** Why group decimals, integer conversion, and character conversions into `Numeric`? **A:** These operations form the language's scalar representation and conversion boundary (~115 lines) operating between host numeric primitives, bit-widths, and Unicode codepoints.
