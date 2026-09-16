{-| @Program.Eval.Builtin.Numeric — decimal primitives, integer conversions, and character codepoints -}
module Pudu.Eval.Builtin.Numeric
  ( callCharFromCode
  , callCharMethod
  , callConvertInteger
  , callDecimal
  , isDecimalBuiltin
  , roundingOfCode
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

import Pudu.DecimalLiteral
  ( Rounding (..)
  , decimalDivideWith
  , decimalFromInteger
  , decimalRound
  , decimalScaleOf
  , decimalToDouble
  , decimalToInteger
  , parseDecimalText
  )
import Pudu.Eval.Env (Evaluator (..), abortAt)
import Pudu.Eval.Render (valueKind)
import Pudu.Eval.Value
  ( Builtin (..)
  , CharMethod (..)
  , Value (..)
  , builtinName
  , intOf
  )
import Pudu.FloatLiteral (FloatWidth (Float64Width))
import Pudu.IntegerLiteral (integerKindFits, integerKindOf)
import Pudu.Source (Span)

{-| Move an integer to another integer type, refusing what will not fit.
    It is the one integer operation that cannot be written in Pudu at all: every
    other one is arithmetic on values of a single type, and this one is the
    boundary between two.

    Answering `None` rather than truncating is the same rule checked arithmetic
    follows. A caller that wants the low bits of a value says so with a mask
    before converting. -}
callConvertInteger :: Span -> [Text] -> [Value] -> Evaluator Value
callConvertInteger spanValue names arguments = case (names, arguments) of
  (target : _, [IntValue _ value]) -> case integerKindOf target of
    Just kind
      | integerKindFits kind value -> pure (VariantValue "Some" [IntValue kind value])
      | otherwise -> pure (VariantValue "None" [])
    Nothing ->
      abortAt (Just spanValue) "E7012"
        (target <> " is not an integer type")
        (Just "convert to one of the integer types, such as UInt8 or Int64")
  ([], _) ->
    abortAt (Just spanValue) "E7012" "convertInteger needs the type to convert to"
      (Just "write it as a type argument, as in convertInteger[UInt8](value)")
  (_, [other]) ->
    abortAt (Just spanValue) "E7012"
      ("convertInteger moves between integers, not from a " <> valueKind other)
      Nothing
  _ -> abortAt (Just spanValue) "E7012" "convertInteger expects one value" Nothing

{-| Whether a built-in is one of the decimal primitives. -}
isDecimalBuiltin :: Builtin -> Bool
isDecimalBuiltin builtin =
  builtin
    `elem` [ DecimalOfBuiltin
           , DecimalFromIntBuiltin
           , DecimalScaleBuiltin
           , DecimalToIntBuiltin
           , DecimalToFloatBuiltin
           , DecimalDivideBuiltin
           , DecimalRoundBuiltin
           ]

{-| Apply a decimal primitive.
    The two that round take the mode as a code rather than a name, because a
    wired-in signature cannot mention a type a library declares. An unrecognised
    code is half-even, which is the mode `Std.Decimal` documents as the default
    and the only one that does not accumulate bias across many roundings. -}
callDecimal :: Span -> Builtin -> [Value] -> Evaluator Value
callDecimal spanValue builtin values = case (builtin, values) of
  (DecimalOfBuiltin, [StrValue text]) -> pure $ case parseDecimalText text of
    Just number -> VariantValue "Some" [DecimalValue number]
    Nothing -> VariantValue "None" []
  (DecimalFromIntBuiltin, [IntValue _ number]) ->
    pure (DecimalValue (decimalFromInteger number))
  (DecimalScaleBuiltin, [DecimalValue number]) ->
    pure (intOf (toInteger (decimalScaleOf number)))
  (DecimalToIntBuiltin, [DecimalValue number]) -> pure $ case decimalToInteger number of
    Just whole -> VariantValue "Some" [intOf whole]
    Nothing -> VariantValue "None" []
  (DecimalToFloatBuiltin, [DecimalValue number]) ->
    pure (FloatValue Float64Width (decimalToDouble number))
  (DecimalDivideBuiltin, [DecimalValue left, DecimalValue right, IntValue _ digits, IntValue _ mode]) ->
    pure $ case decimalDivideWith (fromInteger digits) (roundingOfCode mode) left right of
      Right number -> VariantValue "Some" [DecimalValue number]
      Left _ -> VariantValue "None" []
  (DecimalRoundBuiltin, [DecimalValue number, IntValue _ digits, IntValue _ mode]) ->
    pure (DecimalValue (decimalRound (fromInteger digits) (roundingOfCode mode) number))
  _ ->
    abortAt (Just spanValue) "E7012"
      (builtinName builtin <> " was given arguments it does not accept")
      Nothing

{-| The rounding mode a code selects, in the order `Std.Decimal` declares its
    `Rounding` cases. -}
roundingOfCode :: Integer -> Rounding
roundingOfCode code = case code of
  0 -> RoundUp
  1 -> RoundDown
  2 -> RoundCeiling
  3 -> RoundFloor
  4 -> RoundHalfUp
  5 -> RoundHalfDown
  _ -> RoundHalfEven

{-| Turn a scalar value into a character.
    Not every integer is a Unicode scalar value: the surrogate range and
    anything past U+10FFFF are not, so the answer is an `Option` rather than a
    character the program would then carry around as a lie. -}
callCharFromCode :: Span -> [Value] -> Evaluator Value
callCharFromCode spanValue arguments = case arguments of
  [IntValue _ code]
    | code >= 0
    , code <= 0x10FFFF
    , not (code >= 0xD800 && code <= 0xDFFF) ->
        pure (VariantValue "Some" [CharValue (toEnum (fromInteger code))])
    | otherwise -> pure (VariantValue "None" [])
  _ ->
    abortAt (Just spanValue) "E7012" "charFromCode expects one integer" Nothing

{-| Apply a built-in character method. -}
callCharMethod :: Span -> CharMethod -> Value -> [Value] -> Evaluator Value
callCharMethod spanValue method receiver arguments = case (method, receiver, arguments) of
  (CharCode, CharValue character, []) -> pure (intOf (fromIntegral (fromEnum character)))
  (CharToText, CharValue character, []) -> pure (StrValue (Text.singleton character))
  _ -> abortAt (Just spanValue) "E7012" "wrong arguments for a character method" Nothing
