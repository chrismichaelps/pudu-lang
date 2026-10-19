{-| @Pudu.Backend.Emit.Support — integer descriptors, literals and helper names
    shared by the frame emitter. -}
module Pudu.Backend.Emit.Support
  ( isWideInteger, integerHelper, zeroValue, integerKindText, integerLiteralText
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.State (textOfInt)
import Pudu.Core (CoreType (..))
import Pudu.IntegerLiteral (IntegerKind, integerKindBounds, integerKindWidth, integerKindSigned)

isWideInteger :: IntegerKind -> Bool
isWideInteger kind = integerKindWidth kind == Just 128

integerHelper :: CoreType -> Text -> Text
integerHelper (CoreIntegerType kind) name | isWideInteger kind = "wide_" <> name
integerHelper _ name = name

zeroValue :: CoreType -> Text
zeroValue (CoreIntegerType kind) = integerLiteralText kind 0
zeroValue _ = "0"

integerKindText :: IntegerKind -> Maybe Text
integerKindText kind
  | isWideInteger kind = Just ("(pudu_wide_kind){" <> (if integerKindSigned kind then "1" else "0") <> "}")
  | otherwise = case (integerKindBounds kind, integerKindWidth kind) of
      (Just (low, high), Just width) | width > 0 && width <= 64 ->
        Just ("(pudu_int_kind){UINT64_C(" <> textOfInteger high <> "), UINT64_C("
          <> textOfInteger (negate low) <> "), " <> textOfInt width <> ", "
          <> (if integerKindSigned kind then "1" else "0") <> "}")
      _ -> Nothing

integerLiteralText :: IntegerKind -> Integer -> Text
integerLiteralText kind number
  | isWideInteger kind =
      let wordBits = number `mod` (2^(128::Int))
          base = 2^(64::Int)
       in "(pudu_wide_int){{UINT64_C(" <> textOfInteger (wordBits `mod` base)
            <> "), UINT64_C(" <> textOfInteger (wordBits `div` base) <> ")}, "
            <> (if number < 0 then "1" else "0") <> "}"
  | otherwise =
      "(pudu_int){" <> (if number < 0 then "UINT64_C(0) - " else "")
        <> "UINT64_C(" <> textOfInteger (abs number) <> "), "
        <> (if number < 0 then "1" else "0") <> "}"

textOfInteger :: Integer -> Text
textOfInteger = Text.pack . show
