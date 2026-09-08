{-| @Pudu.DecimalLiteral.Module — exact base-ten numbers and their rounding -}
module Pudu.DecimalLiteral
  ( Decimal (..)
  , DivisionFailure (..)
  , Rounding (..)
  , decimalAdd
  , decimalCompare
  , decimalDivideExact
  , decimalDivideWith
  , decimalFromInteger
  , decimalIsZero
  , decimalMultiply
  , decimalNegate
  , decimalRound
  , decimalScaleOf
  , decimalSubtract
  , decimalSuffix
  , decimalToDouble
  , decimalToInteger
  , parseDecimalLiteral
  , parseDecimalText
  , renderDecimal
  , roundingFromText
  , roundingNames
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

{-| @DecimalLiteral.Value — a coefficient and a base-ten scale.

    The number is @coefficient * 10 ^ (-scale)@, and the scale is never
    negative: a literal written with a positive exponent is normalised into the
    coefficient instead, so every value has one canonical form for a given
    number of fractional digits.

    Trailing zeros are kept. @1.50@ and @1.5@ are the same *number* and compare
    equal, but they are not the same *value*, because a scale is a statement
    about precision — a price written to cents claims cents — and normalising it
    away would discard something the writer said deliberately. Only rendering
    and `decimalScaleOf` can tell them apart. -}
data Decimal = Decimal
  { decimalCoefficient :: !Integer
  , decimalScale :: !Int
  }
  deriving stock (Eq, Show)

{-| @DecimalLiteral.Rounding — what to do with a digit that does not fit.

    All seven modes every base-ten standard converges on. Offering a subset
    would only push programs into writing worse versions of the missing ones. -}
data Rounding
  = RoundUp
  | RoundDown
  | RoundCeiling
  | RoundFloor
  | RoundHalfUp
  | RoundHalfDown
  | RoundHalfEven
  deriving stock (Eq, Ord, Show, Enum, Bounded)

{-| Why a division produced no value. Separated from a plain failure because
    the two have different fixes: a zero divisor is a bug in the program, while
    a non-terminating quotient is a request for `divide` with a stated
    precision. -}
data DivisionFailure
  = DivideByZero
  | NonTerminating
  deriving stock (Eq, Show)

decimalSuffix :: Text
decimalSuffix = "d"

roundingNames :: [(Text, Rounding)]
roundingNames =
  [ ("Up", RoundUp)
  , ("Down", RoundDown)
  , ("Ceiling", RoundCeiling)
  , ("Floor", RoundFloor)
  , ("HalfUp", RoundHalfUp)
  , ("HalfDown", RoundHalfDown)
  , ("HalfEven", RoundHalfEven)
  ]

roundingFromText :: Text -> Maybe Rounding
roundingFromText name = lookup name roundingNames

decimalScaleOf :: Decimal -> Int
decimalScaleOf = decimalScale

decimalIsZero :: Decimal -> Bool
decimalIsZero value = decimalCoefficient value == 0

decimalFromInteger :: Integer -> Decimal
decimalFromInteger value = Decimal value 0

{-| The whole number a decimal names, when it names one exactly. -}
decimalToInteger :: Decimal -> Maybe Integer
decimalToInteger (Decimal coefficient scale)
  | scale <= 0 = Just coefficient
  | remainder == 0 = Just quotient
  | otherwise = Nothing
 where
  divisor = tenTo scale
  (quotient, remainder) = coefficient `quotRem` divisor

{-| Documented as lossy in both directions it can be: a coefficient may carry
    more significant digits than binary64 holds, and a terminating base-ten
    fraction is usually not one in base two. -}
decimalToDouble :: Decimal -> Double
decimalToDouble (Decimal coefficient scale) =
  fromRational (toRational coefficient / toRational (tenTo scale))

decimalNegate :: Decimal -> Decimal
decimalNegate (Decimal coefficient scale) = Decimal (negate coefficient) scale

{-| Bring two values to a common scale without changing either number. -}
align :: Decimal -> Decimal -> (Integer, Integer, Int)
align (Decimal leftCoefficient leftScale) (Decimal rightCoefficient rightScale) =
  ( leftCoefficient * tenTo (target - leftScale)
  , rightCoefficient * tenTo (target - rightScale)
  , target
  )
 where
  target = max leftScale rightScale

decimalAdd :: Decimal -> Decimal -> Decimal
decimalAdd left right =
  let (leftCoefficient, rightCoefficient, scale) = align left right
   in Decimal (leftCoefficient + rightCoefficient) scale

decimalSubtract :: Decimal -> Decimal -> Decimal
decimalSubtract left right =
  let (leftCoefficient, rightCoefficient, scale) = align left right
   in Decimal (leftCoefficient - rightCoefficient) scale

{-| The result scale is the sum of the operand scales, which is exactly the
    number of fractional digits the product has. Nothing rounds. -}
decimalMultiply :: Decimal -> Decimal -> Decimal
decimalMultiply (Decimal leftCoefficient leftScale) (Decimal rightCoefficient rightScale) =
  Decimal (leftCoefficient * rightCoefficient) (leftScale + rightScale)

decimalCompare :: Decimal -> Decimal -> Ordering
decimalCompare left right =
  let (leftCoefficient, rightCoefficient, _) = align left right
   in compare leftCoefficient rightCoefficient

{-| Divide exactly, or say why it cannot be done.

    A quotient terminates in base ten exactly when its denominator, in lowest
    terms, has no prime factor but two and five. That is the whole test, and it
    is decided here rather than approximated by trying a fixed number of digits
    and checking the remainder. -}
decimalDivideExact :: Decimal -> Decimal -> Either DivisionFailure Decimal
decimalDivideExact (Decimal leftCoefficient leftScale) (Decimal rightCoefficient rightScale)
  | rightCoefficient == 0 = Left DivideByZero
  | leftCoefficient == 0 = Right (Decimal 0 0)
  | remaining /= 1 = Left NonTerminating
  | otherwise = Right (rescaleNonNegative (numerator * multiplier) (digits + leftScale - rightScale))
 where
  divisor = gcd leftCoefficient rightCoefficient
  reducedNumerator = leftCoefficient `quot` divisor
  reducedDenominator = rightCoefficient `quot` divisor
  sign = if reducedDenominator < 0 then (-1) else 1
  numerator = sign * reducedNumerator
  denominator = abs reducedDenominator
  (afterTwos, twos) = stripFactor 2 denominator
  (remaining, fives) = stripFactor 5 afterTwos
  digits = max twos fives
  multiplier = tenTo digits `quot` denominator

{-| Divide to a stated number of fractional digits, rounding as told.

    This never reports a non-terminating quotient, because the caller has
    already said what to do about one. Only a zero divisor remains a failure. -}
decimalDivideWith :: Int -> Rounding -> Decimal -> Decimal -> Either DivisionFailure Decimal
decimalDivideWith digits mode (Decimal leftCoefficient leftScale) (Decimal rightCoefficient rightScale)
  | rightCoefficient == 0 = Left DivideByZero
  | otherwise = Right (Decimal rounded target)
 where
  target = max 0 digits
  shift = rightScale - leftScale + target
  numerator = if shift >= 0 then leftCoefficient * tenTo shift else leftCoefficient
  denominator = if shift >= 0 then rightCoefficient else rightCoefficient * tenTo (negate shift)
  rounded = roundedQuotient mode numerator denominator

{-| Round to a number of fractional digits.

    Asking for more digits than the value carries is exact: the value is
    rescaled and nothing is decided. Asking for fewer is where the mode acts. -}
decimalRound :: Int -> Rounding -> Decimal -> Decimal
decimalRound digits mode (Decimal coefficient scale)
  | target >= scale = Decimal (coefficient * tenTo (target - scale)) target
  | otherwise = Decimal (roundedQuotient mode coefficient (tenTo (scale - target))) target
 where
  target = max 0 digits

{-| Divide two integers, deciding the last digit by the given mode.

    The sign is taken out first so every mode is written about magnitudes, which
    is the only way `Ceiling` and `Floor` stay distinguishable from `Up` and
    `Down` without a second set of cases. -}
roundedQuotient :: Rounding -> Integer -> Integer -> Integer
roundedQuotient mode numerator denominator
  | denominator == 0 = 0
  | remainder == 0 = sign * quotient
  | otherwise = sign * (quotient + increment)
 where
  sign = if (numerator < 0) /= (denominator < 0) then -1 else 1
  absoluteNumerator = abs numerator
  absoluteDenominator = abs denominator
  (quotient, remainder) = absoluteNumerator `quotRem` absoluteDenominator
  doubled = compare (2 * remainder) absoluteDenominator
  increment = case mode of
    RoundUp -> 1
    RoundDown -> 0
    RoundCeiling -> if sign > 0 then 1 else 0
    RoundFloor -> if sign < 0 then 1 else 0
    RoundHalfUp -> if doubled == LT then 0 else 1
    RoundHalfDown -> if doubled == GT then 1 else 0
    RoundHalfEven -> case doubled of
      GT -> 1
      LT -> 0
      EQ -> if even quotient then 0 else 1

{-| Give a value a non-negative scale, folding a negative one into the
    coefficient so every value has the canonical form the type promises. -}
rescaleNonNegative :: Integer -> Int -> Decimal
rescaleNonNegative coefficient scale
  | scale >= 0 = Decimal coefficient scale
  | otherwise = Decimal (coefficient * tenTo (negate scale)) 0

stripFactor :: Integer -> Integer -> (Integer, Int)
stripFactor factor = go 0
 where
  go count value
    | value /= 0, value `rem` factor == 0 = go (count + 1) (value `quot` factor)
    | otherwise = (value, count)

tenTo :: Int -> Integer
tenTo power
  | power <= 0 = 1
  | otherwise = 10 ^ power

{-| Render a decimal with exactly the fractional digits its scale claims. -}
renderDecimal :: Decimal -> Text
renderDecimal (Decimal coefficient scale)
  | scale <= 0 = Text.pack (show coefficient)
  | otherwise = signText <> wholePart <> "." <> fractionPart
 where
  signText = if coefficient < 0 then "-" else Text.empty
  digits = Text.pack (show (abs coefficient))
  padded = Text.justifyRight (scale + 1) '0' digits
  wholePart = Text.dropEnd scale padded
  fractionPart = Text.takeEnd scale padded

{-| Read the body of a decimal literal, with or without its `d` suffix.

    Underscores are separators and are dropped, matching every other numeric
    literal. An exponent shifts the scale rather than producing a float, so
    `1e6d` is the exact whole number and not an approximation of it. -}
parseDecimalLiteral :: Text -> Maybe Decimal
parseDecimalLiteral source = parseDecimalText body
 where
  body = maybe source id (Text.stripSuffix decimalSuffix source)

{-| Read decimal text with no suffix, as `Decimal.parse` does at run time. -}
parseDecimalText :: Text -> Maybe Decimal
parseDecimalText source = do
  let cleaned = Text.filter (/= '_') (Text.strip source)
  (mantissa, exponent') <- splitExponent cleaned
  (coefficient, scale) <- readMantissa mantissa
  let shifted = scale - exponent'
  pure (rescaleNonNegative coefficient shifted)

splitExponent :: Text -> Maybe (Text, Int)
splitExponent text = case Text.break (\scalar -> scalar == 'e' || scalar == 'E') text of
  (mantissa, rest)
    | Text.null rest -> Just (mantissa, 0)
    | otherwise -> do
        value <- readSignedInteger (Text.drop 1 rest)
        pure (mantissa, fromIntegral value)

readMantissa :: Text -> Maybe (Integer, Int)
readMantissa text = do
  (negative, unsigned) <- splitSign text
  let (wholePart, rest) = Text.break (== '.') unsigned
      fractionPart = Text.drop 1 rest
  if Text.null rest
    then do
      whole <- readDigits wholePart
      pure (applySign negative whole, 0)
    else do
      _ <- if Text.null wholePart && Text.null fractionPart then Nothing else Just ()
      whole <- if Text.null wholePart then Just 0 else readDigits wholePart
      fraction <- if Text.null fractionPart then Just 0 else readDigits fractionPart
      let scale = Text.length fractionPart
      pure (applySign negative (whole * tenTo scale + fraction), scale)

readSignedInteger :: Text -> Maybe Integer
readSignedInteger text = do
  (negative, unsigned) <- splitSign text
  value <- readDigits unsigned
  pure (applySign negative value)

splitSign :: Text -> Maybe (Bool, Text)
splitSign text = case Text.uncons text of
  Just ('-', rest) -> Just (True, rest)
  Just ('+', rest) -> Just (False, rest)
  Just _ -> Just (False, text)
  Nothing -> Nothing

applySign :: Bool -> Integer -> Integer
applySign negative value = if negative then negate value else value

readDigits :: Text -> Maybe Integer
readDigits text
  | Text.null text = Nothing
  | Text.all isAsciiDigit text = Just (Text.foldl' step 0 text)
  | otherwise = Nothing
 where
  step accumulated scalar = accumulated * 10 + toInteger (fromEnum scalar - fromEnum '0')
  isAsciiDigit scalar = scalar >= '0' && scalar <= '9'
