---
type: module
path: "@root/src/Pudu/FloatLiteral.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.58
depth_status: MEDIUM
tags: [module, medium, numeric]
aliases: [Float Literal]
---

# Float Literal

## Purpose

Own the closed floating suffix vocabulary, total textual conversion, representability check, and runtime precision normalization shared by scanning, typing, and evaluation.

## Interface

```haskell
data FloatWidth = Float32Width | Float64Width
data ParsedFloat = ParsedFloat
  { parsedFloatValue :: !Double
  , parsedFloatWidth :: !FloatWidth
  , parsedFloatFits :: !Bool
  }
floatSuffix :: Text -> Maybe FloatWidth
floatWidthType :: FloatWidth -> Text
splitFloatSuffix :: Text -> (Text, Maybe FloatWidth)
parseFloatLiteral :: Text -> Maybe ParsedFloat
normalizeFloat :: FloatWidth -> Double -> Double
```

## Governance

- The closed lowercase suffixes are `f32` and `f64`. A suffix is part of the floating token; no suffix means `Float64` and context never narrows it implicitly.
- Conversion removes only lexer-admitted separators and uses total `readMaybe`. `Float32` conversion uses the direct `double2Float`/`float2Double` base operations confirmed through [Hoogle](https://hoogle.haskell.org/?hoogle=double2Float), avoiding the documented `realToFrac` optimization caveat.
- A parsed infinity means the finite source spelling exceeded the selected IEEE width. Typing reports `E3019`; the value is never admitted to evaluation.
- Runtime values retain `FloatWidth`. Every `Float32` literal and arithmetic result is normalized through binary32, so the interpreter does not present a statically narrow type while calculating at binary64 precision.
- GHC's official [`FractionalLit`](https://github.com/ghc/ghc/blob/master/compiler/Language/Haskell/Syntax/Lit.hs) is the representation reference: source spelling and exponent intent remain available before the selected representation is produced. GHC's [`mkLitFloat`/`mkLitDouble`](https://github.com/ghc/ghc/blob/master/compiler/GHC/Types/Literal.hs) are the lowering reference for selecting binary32 versus binary64 from one fractional source value.

## Algorithm

Split a known suffix, remove separators, and use `readMaybe` at the selected host IEEE type. Convert a finite `Float32` through `float2Double` for storage; retain a `Float64` directly. `normalizeFloat` applies the same binary32 round trip to every narrow runtime result and is identity for binary64.

## Negative Logic

- No implicit `Float64` to `Float32` narrowing, hexadecimal floats, decimal arithmetic, exceptions, partial `read`, silent infinity admission, or type-checker state.

## Edge Cases

- `1.0f32` is `Float32`; `1.0`, `1.0f64`, and `1e0f64` are `Float64`.
- `16777217.0f32` evaluates as `16777216.0`, the nearest binary32 value, while the `f64` spelling retains `16777217.0`.
- A finite spelling above the selected maximum reports `E3019`. Underflow rounds to signed zero and remains admitted, matching IEEE conversion.
- Unary minus is outside the token. Negating a zero-valued runtime float therefore preserves negative zero at the selected precision.

## Depth

DEPTH 0.58 (MEDIUM). One total cross-phase boundary prevents scanner, checker, patterns, and evaluator from disagreeing about suffix ownership or precision.

## Grill Log

- **Q:** Let an unsuffixed literal contextually become `Float32`? **A:** No; require `f32`. _Rationale:_ the language prohibits implicit precision-losing conversion, and a suffix makes the loss visible at the literal. _Rejected:_ deferred float defaulting; implicit narrowing; a conversion that exists only in typing.
- **Q:** Type a suffix as `Float32` but keep calculating with `Double`? **A:** No; retain width on runtime values and normalize every narrow result. _Rationale:_ a static-only width would make observable arithmetic contradict the declared type. _Rejected:_ erasing width after checking; rounding only the initial literal.
- **Q:** Use partial `read` or `realToFrac`? **A:** No; use `readMaybe` and direct base conversions. _Rationale:_ source failures remain typed, and Hoogle documents an optimization-sensitive `realToFrac` caveat. _Rejected:_ exception recovery; O0/O2-sensitive conversion.

## Referenced by

[[src/Pudu/_MOC]] · [[Number Scanner]] · [[Type Check Rule]] · [[Eval Value]] · [[Eval Match]] · [[Eval Operator]]
