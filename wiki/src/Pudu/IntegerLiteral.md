---
type: module
path: "@root/src/Pudu/IntegerLiteral.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.66
depth_status: MEDIUM
tags: [module, medium, numeric]
aliases: [Integer Literal]
---

# Integer Literal

## Purpose

Decode one already lexically admitted integer spelling into an arbitrary-precision mathematical value plus an optional fixed-width suffix, and answer whether that value fits a concrete Pudu integer type.

## Interface

```haskell
data IntegerSuffix = SignedSuffix !Int | UnsignedSuffix !Int
data ParsedInteger = ParsedInteger
  { parsedIntegerValue :: !Integer
  , parsedIntegerSuffix :: !(Maybe IntegerSuffix)
  }
integerSuffix :: Text -> Maybe IntegerSuffix
integerSuffixType :: IntegerSuffix -> Text
splitIntegerSuffix :: Text -> (Text, Maybe IntegerSuffix)
parseIntegerLiteral :: Text -> Maybe ParsedInteger
fitsIntegerType :: Int -> Text -> Integer -> Maybe Bool
```

## Governance

- **Arbitrary precision absorbs.** A `BigInt` met with anything narrower stays a `BigInt`. The rule
  was originally the reverse, and that overflowed `total * 10 + digit` part way through a number
  `BigInt` was chosen to hold — carrying a mixed result in the narrower type is the quiet truncation
  checked arithmetic exists to prevent.

- `IntegerKind` is the width and signedness a value carries at run time. `Int` and `UInt` keep their
  own constructors rather than being written as the target's width, because they are distinct types:
  an implementation for `Int` is not an implementation for `Int64`, however wide the target is.
- `targetPointerWidth` is the one place the target's width is written down, so the day a target
  becomes selectable there is one place to change.
- `integerKindWrap` is used only where wrapping is the *defined* answer — the bitwise operations,
  where a mask is what the operation means — never to rescue an arithmetic result that overflowed.

- Exact token text stays owned by the frontend. This module decodes only after scanning, using host `Integer` so source magnitude is never truncated.
- Suffixes are the closed lowercase set `i8`, `i16`, `i32`, `i64`, `i128`, `u8`, `u16`, `u32`, `u64`, and `u128`. Unsuffixed literals remain context-selectable and default to `Int` only after inference.
- Decimal, binary, octal, and hexadecimal bodies share one strict digit fold. `_` is ignored only after the lexer has proved separator placement.
- `fitsIntegerType` recognizes compiler-wired `Int*`, `UInt*`, and `BigInt`. It receives the target `Int` width explicitly; a non-integer type returns `Nothing` rather than being treated as an out-of-range integer.

## Algorithm

Strip a leading sign, split a known suffix, select the radix from a lowercase prefix, and fold each remaining scalar into an arbitrary-precision `Integer`. Fit checking compares that value with the exact signed or unsigned mathematical interval; `BigInt` is unbounded.

## Negative Logic

- No token emission, type-variable state, implicit widening/narrowing, runtime representation, floating parsing, partial `read`, or host fixed-width conversion.

## Edge Cases

- `127i8` and `-128i8` fit; `128i8` and `-129i8` do not.
- `0u8` and `255u8` fit; `-1u8` and `256u8` do not.
- Base-prefixed forms such as `0xffu8` retain their suffix while decoding the body in its declared radix.
- `BigInt` accepts every decoded magnitude; `Int`/`UInt` use the target width supplied by the checker.

## Depth

DEPTH 0.66 (MEDIUM). One total boundary centralizes suffix vocabulary, arbitrary-precision decoding, and mathematical fit laws for lexer, checker, and evaluator consumers.

## Grill Log

- **Q:** Parse through host `Int` or partial `read`? **A:** No; fold into arbitrary-precision `Integer`. _Rationale:_ source magnitude and target width must not depend on the compiler host's fixed-width conversion. _Rejected:_ `read Int`; truncating conversion; exception recovery.
- **Q:** Encode suffixes as separate identifier tokens? **A:** No; the number scanner owns a contiguous known suffix. _Rationale:_ `1i8` is one literal and an unknown suffix should receive one numeric diagnostic rather than a parser cascade. _Rejected:_ integer-plus-identifier token pairs; parser adjacency rules.
- **Q:** Default every unsuffixed literal immediately? **A:** No; register a deferred constraint and default only if context leaves it unresolved. _Rationale:_ `let x: Int8 = 1` must select `Int8` while bare `1` remains ergonomic. _Rejected:_ hard-coded `Int`; global overloaded-number traits in this slice.

## Referenced by

[[src/Pudu/_MOC]] · [[Number Scanner]] · [[Type Env]] · [[Eval Match]]
