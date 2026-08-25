{-| @Test.DecimalLiteral — the exactness and rounding laws ADR-0007 states -}
module Pudu.DecimalLiteralSpec (decimalProperties) where

import Data.Maybe (fromMaybe)
import Pudu.DecimalLiteral
  ( Decimal (..)
  , DivisionFailure (DivideByZero, NonTerminating)
  , Rounding (..)
  , decimalAdd
  , decimalCompare
  , decimalDivideExact
  , decimalDivideWith
  , decimalFromInteger
  , decimalMultiply
  , decimalRound
  , decimalSubtract
  , decimalToDouble
  , decimalToInteger
  , parseDecimalLiteral
  , parseDecimalText
  , renderDecimal
  )
import Test.QuickCheck
  ( Gen
  , Property
  , chooseInt
  , chooseInteger
  , conjoin
  , counterexample
  , forAll
  , property
  , (===)
  )

decimalProperties :: [(String, IO Property)]
decimalProperties =
  [ ("decimal literals read exactly as written", testLiterals)
  , ("addition and subtraction are exact at the wider scale", testAdditive)
  , ("multiplication scale is the sum of the operand scales", testProductScale)
  , ("equality follows the number and rendering follows the scale", testScaleVersusValue)
  , ("division is exact or says why it cannot be", testExactDivision)
  , ("every rounding mode decides a half differently", testRoundingModes)
  , ("rounding to more digits never changes the number", testWideningIsExact)
  , ("stated precision always answers except on a zero divisor", testStatedPrecision)
  , ("conversions preserve what they claim to", testConversions)
  ]

{-| Values with small coefficients and scales; the laws hold at every size, and
    a bounded generator keeps a counterexample readable. -}
decimals :: Gen Decimal
decimals = Decimal <$> chooseInteger (-100000, 100000) <*> chooseInt (0, 6)

nonZeroDecimals :: Gen Decimal
nonZeroDecimals = do
  value <- decimals
  pure (if decimalCoefficient value == 0 then value{decimalCoefficient = 1} else value)

testLiterals :: IO Property
testLiterals =
  pure $ conjoin
    [ parseDecimalLiteral "1.50d" === Just (Decimal 150 2)
    , counterexample "a whole literal has scale nought"
        (parseDecimalLiteral "3d" === Just (Decimal 3 0))
    , counterexample "an exponent shifts the scale rather than approximating"
        (parseDecimalLiteral "1e6d" === Just (Decimal 1000000 0))
    , parseDecimalLiteral "1.5e-3d" === Just (Decimal 15 4)
    , counterexample "underscores separate digits here as everywhere"
        (parseDecimalLiteral "1_000.50d" === Just (Decimal 100050 2))
    , parseDecimalLiteral "-2.25d" === Just (Decimal (-225) 2)
    , counterexample "the suffix is optional for run-time text"
        (parseDecimalText "0.001" === Just (Decimal 1 3))
    , parseDecimalText "not a number" === Nothing
    , parseDecimalText "" === Nothing
    , parseDecimalText "1.2.3" === Nothing
    ]

testAdditive :: IO Property
testAdditive =
  pure $ forAll decimals $ \left -> forAll decimals $ \right ->
    let sum' = decimalAdd left right
        difference = decimalSubtract left right
        wider = max (decimalScale left) (decimalScale right)
     in conjoin
          [ counterexample "a sum carries the wider scale" (decimalScale sum' === wider)
          , counterexample "a difference carries the wider scale"
              (decimalScale difference === wider)
          , counterexample "subtracting what was added returns the value"
              (decimalCompare (decimalSubtract sum' right) left === EQ)
          , counterexample "addition commutes"
              (decimalCompare sum' (decimalAdd right left) === EQ)
          ]

testProductScale :: IO Property
testProductScale =
  pure $ forAll decimals $ \left -> forAll decimals $ \right ->
    let product' = decimalMultiply left right
     in conjoin
          [ decimalScale product' === decimalScale left + decimalScale right
          , counterexample "multiplication commutes"
              (decimalCompare product' (decimalMultiply right left) === EQ)
          ]

{-| The one place the type deliberately distinguishes what it stores from what
    it compares. `1.50d` and `1.5d` are the same number; only rendering and the
    scale can tell them apart. -}
testScaleVersusValue :: IO Property
testScaleVersusValue =
  pure $ conjoin
    [ decimalCompare (Decimal 150 2) (Decimal 15 1) === EQ
    , renderDecimal (Decimal 150 2) === "1.50"
    , renderDecimal (Decimal 15 1) === "1.5"
    , counterexample "a rendered value always has the digits its scale claims"
        (renderDecimal (Decimal 1 3) === "0.001")
    , renderDecimal (Decimal (-1) 3) === "-0.001"
    , renderDecimal (Decimal 0 2) === "0.00"
    , renderDecimal (Decimal 42 0) === "42"
    , counterexample "rendering round-trips through parsing"
        (forAll decimals (\value -> parseDecimalText (renderDecimal value) === Just value))
    ]

testExactDivision :: IO Property
testExactDivision =
  pure $ conjoin
    [ decimalDivideExact (Decimal 1 0) (Decimal 4 0) === Right (Decimal 25 2)
    , decimalDivideExact (Decimal 1 0) (Decimal 8 0) === Right (Decimal 125 3)
    , counterexample "a quotient with a factor of three does not terminate"
        (decimalDivideExact (Decimal 1 0) (Decimal 3 0) === Left NonTerminating)
    , decimalDivideExact (Decimal 1 0) (Decimal 0 0) === Left DivideByZero
    , counterexample "nought divided by anything is nought"
        (decimalDivideExact (Decimal 0 2) (Decimal 7 0) === Right (Decimal 0 0))
    , counterexample "an exact quotient multiplied back gives the dividend"
        ( forAll decimals $ \left -> forAll nonZeroDecimals $ \right ->
            case decimalDivideExact left right of
              Left _ -> property True
              Right quotient ->
                decimalCompare (decimalMultiply quotient right) left === EQ
        )
    ]

testRoundingModes :: IO Property
testRoundingModes =
  pure $ conjoin
    [ counterexample "half-up leaves the half behind"
        (roundedWhole RoundHalfUp (Decimal 5 1) === 1)
    , roundedWhole RoundHalfDown (Decimal 5 1) === 0
    , counterexample "half-even prefers the even neighbour"
        (roundedWhole RoundHalfEven (Decimal 5 1) === 0)
    , roundedWhole RoundHalfEven (Decimal 15 1) === 2
    , roundedWhole RoundHalfEven (Decimal 25 1) === 2
    , roundedWhole RoundHalfEven (Decimal 35 1) === 4
    , counterexample "up and down follow the magnitude"
        (roundedWhole RoundUp (Decimal 1 1) === 1)
    , roundedWhole RoundDown (Decimal 9 1) === 0
    , roundedWhole RoundUp (Decimal (-1) 1) === (-1)
    , roundedWhole RoundDown (Decimal (-9) 1) === 0
    , counterexample "ceiling and floor follow the number line"
        (roundedWhole RoundCeiling (Decimal (-5) 1) === 0)
    , roundedWhole RoundFloor (Decimal (-5) 1) === (-1)
    , roundedWhole RoundCeiling (Decimal 1 1) === 1
    , roundedWhole RoundFloor (Decimal 9 1) === 0
    ]
 where
  roundedWhole mode value = decimalCoefficient (decimalRound 0 mode value)

testWideningIsExact :: IO Property
testWideningIsExact =
  pure $ forAll decimals $ \value -> forAll (chooseInt (0, 4)) $ \extra ->
    let target = decimalScale value + extra
        widened = decimalRound target RoundHalfEven value
     in conjoin
          [ counterexample "the number is unchanged" (decimalCompare widened value === EQ)
          , counterexample "the scale is the one asked for" (decimalScale widened === target)
          ]

testStatedPrecision :: IO Property
testStatedPrecision =
  pure $ conjoin
    [ decimalDivideWith 5 RoundHalfEven (Decimal 1 0) (Decimal 3 0) === Right (Decimal 33333 5)
    , decimalDivideWith 4 RoundHalfEven (Decimal 2 0) (Decimal 3 0) === Right (Decimal 6667 4)
    , decimalDivideWith 0 RoundHalfEven (Decimal 1 0) (Decimal 2 0) === Right (Decimal 0 0)
    , counterexample "only a zero divisor still fails"
        (decimalDivideWith 5 RoundHalfEven (Decimal 1 0) (Decimal 0 0) === Left DivideByZero)
    , counterexample "a stated precision always answers otherwise"
        ( forAll decimals $ \left -> forAll nonZeroDecimals $ \right ->
            case decimalDivideWith 8 RoundHalfEven left right of
              Right quotient -> decimalScale quotient === 8
              Left _ -> property False
        )
    ]

testConversions :: IO Property
testConversions =
  pure $ conjoin
    [ counterexample "every whole number is exactly representable"
        (forAll (chooseInteger (-10000, 10000)) (\n -> decimalToInteger (decimalFromInteger n) === Just n))
    , decimalToInteger (Decimal 300 2) === Just 3
    , counterexample "a fractional part has no whole answer"
        (decimalToInteger (Decimal 350 2) === Nothing)
    , counterexample "the float conversion is near, not exact"
        (property (abs (decimalToDouble (Decimal 1 1) - 0.1) < 1.0e-12))
    , counterexample "a decimal tenth is not the float that prints as one"
        (property (decimalToDouble (decimalOf "0.1") /= sumOfThreeTenths))
    ]
 where
  decimalOf text = fromMaybe (Decimal 0 0) (parseDecimalText text)
  sumOfThreeTenths = 0.1 + 0.2 - 0.2 + 1.0e-17
