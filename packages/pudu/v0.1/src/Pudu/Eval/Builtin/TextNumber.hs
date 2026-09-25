{-| @Program.Eval.Builtin.TextNumber — reading a number that text spells

    `value.toText()` writes any value as text; these read the three number
    kinds back. Each answers `Nothing` rather than failing, because text that
    is not a number is an ordinary input, and each reads the whole text: a
    number followed by anything, or preceded by a space, is not a number here.
    A reader trims first when it means to, which keeps `" 42"` from being
    accepted in one place and refused in another.

    The float reader is here rather than in the library for the reason the
    digests are in `Pudu.Eval.Hash`: the correctly rounded conversion from
    decimal digits to binary64 is subtle, and one written in the language
    would be both slow and wrong in its last bit. -}
module Pudu.Eval.Builtin.TextNumber
  ( readWhole
  , readFloat
  , readDecimal
  ) where

import Data.Char (isDigit)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as Text

import Pudu.DecimalLiteral (Decimal, parseDecimalText)

{-| An optional sign and one or more ASCII digits, fitting a platform `Int`. -}
readWhole :: Text -> Maybe Integer
readWhole text = do
  (negative, digits) <- signed text
  if Text.null digits || not (Text.all isDigit digits)
    then Nothing
    else
      let magnitude = Text.foldl' (\total digit -> total * 10 + toInteger (fromEnum digit - fromEnum '0')) 0 digits
          value = if negative then negate magnitude else magnitude
       in if value < toInteger (minBound :: Int64) || value > toInteger (maxBound :: Int64)
            then Nothing
            else Just value

{-| An optional sign, digits with an optional point (digits on at least one
    side of it), and an optional exponent, answered only when the result is
    finite. `inf` and `nan` are not numbers a person writes as input and are
    refused, as is a value too large for binary64. -}
readFloat :: Text -> Maybe Double
readFloat text = do
  (negative, unsigned) <- signed text
  let (mantissa, exponentPart) = Text.break (\c -> c == 'e' || c == 'E') unsigned
      (whole, pointAndFraction) = Text.break (== '.') mantissa
      fraction = Text.drop 1 pointAndFraction
  if not (Text.all isDigit whole && Text.all isDigit fraction)
    || (Text.null whole && Text.null fraction)
    || Text.count "." mantissa > 1
    then Nothing
    else do
      exponentText <- exponentOf exponentPart
      let normalized =
            (if Text.null whole then "0" else whole)
              <> "."
              <> (if Text.null fraction then "0" else fraction)
              <> exponentText
      case reads (Text.unpack normalized) :: [(Double, String)] of
        [(value, "")]
          | isInfinite value || isNaN value -> Nothing
          | otherwise -> Just (if negative then negate value else value)
        _ -> Nothing
 where
  exponentOf part
    | Text.null part = Just ""
    | otherwise = do
        (negative, digits) <- signed (Text.drop 1 part)
        if Text.null digits || not (Text.all isDigit digits) || Text.length digits > 6
          then Nothing
          else Just ("e" <> (if negative then "-" else "") <> digits)

{-| An exact decimal written in full, with no surrounding space and no digit
    separators; the literal reader behind `Std.Decimal.parse` is more lenient,
    and this method agrees with the other two about what the whole text is. -}
readDecimal :: Text -> Maybe Decimal
readDecimal text
  | Text.any (\c -> c == '_' || c == ' ' || c == '\t' || c == '\n' || c == '\r') text = Nothing
  | otherwise = parseDecimalText text

signed :: Text -> Maybe (Bool, Text)
signed text = case Text.uncons text of
  Just ('-', rest) -> Just (True, rest)
  Just ('+', rest) -> Just (False, rest)
  Just _ -> Just (False, text)
  Nothing -> Nothing
