---
type: module
path: "@root/src/Pudu/DecimalLiteral.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.7
depth_status: MEDIUM
tags: [module, medium, numeric]
aliases: [Decimal Literal]
---

# Decimal Literal

## Purpose

Own the exact base-ten number: its representation, its arithmetic, the seven rounding modes, and
the reading and rendering of a decimal spelling. Every decision this module makes is the one
[[ADR-0007]] accepted.

## Interface

```haskell
data Decimal = Decimal { decimalCoefficient :: !Integer, decimalScale :: !Int }
data Rounding = RoundUp | RoundDown | RoundCeiling | RoundFloor
              | RoundHalfUp | RoundHalfDown | RoundHalfEven
data DivisionFailure = DivideByZero | NonTerminating
decimalAdd, decimalSubtract, decimalMultiply :: Decimal -> Decimal -> Decimal
decimalCompare      :: Decimal -> Decimal -> Ordering
decimalDivideExact  :: Decimal -> Decimal -> Either DivisionFailure Decimal
decimalDivideWith   :: Int -> Rounding -> Decimal -> Decimal -> Either DivisionFailure Decimal
decimalRound        :: Int -> Rounding -> Decimal -> Decimal
decimalFromInteger  :: Integer -> Decimal
decimalToInteger    :: Decimal -> Maybe Integer
decimalToDouble     :: Decimal -> Double
parseDecimalLiteral :: Text -> Maybe Decimal
parseDecimalText    :: Text -> Maybe Decimal
renderDecimal       :: Decimal -> Text
```

### Governance

- A value is `coefficient * 10 ^ (-scale)` and the scale is never negative. A literal written with a
  positive exponent is normalised into the coefficient, so a given number of fractional digits has
  exactly one representation.
- **Trailing zeros are kept, and are not compared.** `1.50` and `1.5` are the same number and
  compare equal; only `renderDecimal` and `decimalScale` tell them apart. A scale is a statement
  about precision — an amount written to cents claims cents — so normalising it away would discard
  something the writer said deliberately. Making `==` sensitive to it instead would fail the one
  property every reader assumes of a number.
- Addition, subtraction, and multiplication are exact and cannot round. Their result scales are
  fixed by the operand scales: the wider of the two for a sum or difference, the sum of the two for a
  product. There is no precision context that could truncate one.
- `decimalDivideExact` decides termination rather than approximating it: a quotient terminates in
  base ten exactly when its denominator in lowest terms has no prime factor but two and five, and
  that is the test performed. Trying a fixed digit count and checking the remainder would answer a
  different question.
- `decimalDivideWith` cannot report a non-terminating quotient, because its caller has already
  supplied the precision and the mode. Only a zero divisor remains a failure.
- Every rounding mode is written about magnitudes with the sign taken out first. That is what keeps
  `Ceiling` and `Floor` distinguishable from `Up` and `Down` without a second set of cases.
- Rounding to more digits than a value carries is exact rescaling, not a decision.
- The module is pure and total: nothing here reports a diagnostic, and every partial answer is a
  `Maybe` or an `Either` the caller must handle.

### Linkage

- **Requires:** nothing beyond `Data.Text`.
- **Consumed by:** [[Lexer Number]], [[Type Check Rule]], [[Eval Value]], [[Eval Operator]],
  [[Eval Match]], [[Eval Order]], [[Evaluator]].

## Algorithm

Coefficient arithmetic over arbitrary-precision integers, with alignment to a common scale before
any operation that needs one. Exact division reduces the fraction, strips factors of two and five
from the denominator, and reports `NonTerminating` when anything else remains. Rounding divides
magnitudes and decides the last digit from the doubled remainder compared against the divisor.

## Negative Logic (Prohibited Paths)

- No diagnostics, no evaluator access, and no implicit conversion to or from any other numeric type.
- No global precision or rounding context. A mode is passed at each call that needs one, so nothing
  can change the meaning of arithmetic elsewhere in a program.
- No normalisation of trailing zeros, and no rounding on any path that is not named as rounding.

## Grill Log

- **Q:** Why is division exact-or-error rather than rounded to a context? **A:** Rounding is the
  decimal analogue of integer wrapping — a real answer altered to fit. _Rationale:_ the language
  already refuses silent wrapping and makes `&+` a separate operator; a context that rounds at digit
  29 is invisible by construction. _Rejected:_ a fixed 28- or 34-digit context; rounding to the
  dividend's scale, which would make the answer depend on how the dividend happened to be written.
- **Q:** Why keep trailing zeros when equality ignores them? **A:** Because the two answer different
  questions. _Rationale:_ a monetary amount should keep saying cents through a round trip, and a
  reader still expects `1.50 == 1.5`. _Rejected:_ normalising on construction; making `==` compare
  representations.
- **Q:** Why not build `Decimal` as a library type over `BigInt`? **A:** The literal form has to be
  lexed and typed, and a library type cannot have one. _Rationale:_ half the feature would have
  lived in the compiler regardless. _Rejected:_ splitting the exactness guarantee across the
  boundary, where a user could replace it.

## Referenced by

[[src/Pudu/_MOC]] · [[ADR-0007]] · [[grammar/pudu]] · [[architecture/STDLIB]] · [[Integer Literal]] · [[Float Literal]]
