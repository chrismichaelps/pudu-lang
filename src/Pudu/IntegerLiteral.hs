{-| @Pudu.IntegerLiteral.Module — decodes and bounds integer literals -}
module Pudu.IntegerLiteral
  ( IntegerSuffix (..)
  , ParsedInteger (..)
  , fitsIntegerType
  , integerSuffix
  , integerSuffixType
  , parseIntegerLiteral
  , splitIntegerSuffix
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

data IntegerSuffix
  = SignedSuffix !Int
  | UnsignedSuffix !Int
  deriving stock (Eq, Show)

data ParsedInteger = ParsedInteger
  { parsedIntegerValue :: !Integer
  , parsedIntegerSuffix :: !(Maybe IntegerSuffix)
  }
  deriving stock (Eq, Show)

integerSuffix :: Text -> Maybe IntegerSuffix
integerSuffix text = lookup text suffixes

integerSuffixType :: IntegerSuffix -> Text
integerSuffixType suffix = case suffix of
  SignedSuffix width -> "Int" <> decimalText width
  UnsignedSuffix width -> "UInt" <> decimalText width

splitIntegerSuffix :: Text -> (Text, Maybe IntegerSuffix)
splitIntegerSuffix text = firstSuffix suffixes
 where
  firstSuffix candidates = case candidates of
    [] -> (text, Nothing)
    (suffixText, suffix) : rest -> case Text.stripSuffix suffixText text of
      Just body -> (body, Just suffix)
      Nothing -> firstSuffix rest

parseIntegerLiteral :: Text -> Maybe ParsedInteger
parseIntegerLiteral source = do
  let (sign, unsigned) = case Text.uncons source of
        Just ('-', rest) -> (-1, rest)
        _ -> (1, source)
      (body, suffix) = splitIntegerSuffix unsigned
      (radix, digits) = integerRadix body
  magnitude <- foldDigits radix digits
  pure
    ParsedInteger
      { parsedIntegerValue = sign * magnitude
      , parsedIntegerSuffix = suffix
      }

fitsIntegerType :: Int -> Text -> Integer -> Maybe Bool
fitsIntegerType targetWidth typeName value = case typeName of
  "Int8" -> Just (fitsSigned 8 value)
  "Int16" -> Just (fitsSigned 16 value)
  "Int32" -> Just (fitsSigned 32 value)
  "Int64" -> Just (fitsSigned 64 value)
  "Int128" -> Just (fitsSigned 128 value)
  "Int" -> Just (fitsSigned targetWidth value)
  "UInt8" -> Just (fitsUnsigned 8 value)
  "UInt16" -> Just (fitsUnsigned 16 value)
  "UInt32" -> Just (fitsUnsigned 32 value)
  "UInt64" -> Just (fitsUnsigned 64 value)
  "UInt128" -> Just (fitsUnsigned 128 value)
  "UInt" -> Just (fitsUnsigned targetWidth value)
  "BigInt" -> Just True
  _ -> Nothing

suffixes :: [(Text, IntegerSuffix)]
suffixes =
  [ ("i128", SignedSuffix 128)
  , ("u128", UnsignedSuffix 128)
  , ("i64", SignedSuffix 64)
  , ("u64", UnsignedSuffix 64)
  , ("i32", SignedSuffix 32)
  , ("u32", UnsignedSuffix 32)
  , ("i16", SignedSuffix 16)
  , ("u16", UnsignedSuffix 16)
  , ("i8", SignedSuffix 8)
  , ("u8", UnsignedSuffix 8)
  ]

integerRadix :: Text -> (Int, Text)
integerRadix text
  | Just rest <- Text.stripPrefix "0b" text = (2, rest)
  | Just rest <- Text.stripPrefix "0o" text = (8, rest)
  | Just rest <- Text.stripPrefix "0x" text = (16, rest)
  | otherwise = (10, text)

foldDigits :: Int -> Text -> Maybe Integer
foldDigits radix text = case Text.foldl' step (Just 0, False, 0 :: Int) text of
  (Just value, True, count) | count > 0 -> Just value
  _ -> Nothing
 where
  step (result, previousDigit, count) scalar
    | scalar == '_' =
        (if previousDigit then result else Nothing, False, count)
    | otherwise = case (result, digitValue scalar) of
        (Just accumulated, Just digit)
          | digit < radix ->
              (Just (accumulated * fromIntegral radix + fromIntegral digit), True, count + 1)
        _ -> (Nothing, False, count)

digitValue :: Char -> Maybe Int
digitValue scalar
  | scalar >= '0' && scalar <= '9' = Just (fromEnum scalar - fromEnum '0')
  | scalar >= 'a' && scalar <= 'f' = Just (10 + fromEnum scalar - fromEnum 'a')
  | scalar >= 'A' && scalar <= 'F' = Just (10 + fromEnum scalar - fromEnum 'A')
  | otherwise = Nothing

fitsSigned :: Int -> Integer -> Bool
fitsSigned width value =
  let limit = 2 ^ (width - 1)
   in value >= negate limit && value < limit

fitsUnsigned :: Int -> Integer -> Bool
fitsUnsigned width value = value >= 0 && value < 2 ^ width

decimalText :: Int -> Text
decimalText = Text.pack . show
