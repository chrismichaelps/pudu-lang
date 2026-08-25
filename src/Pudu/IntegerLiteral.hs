{-| @Pudu.IntegerLiteral.Module — decodes and bounds integer literals -}
module Pudu.IntegerLiteral
  ( IntegerKind (..)
  , IntegerSuffix (..)
  , ParsedInteger (..)
  , integerKindFits
  , integerKindMeet
  , integerKindName
  , integerKindOf
  , integerKindSigned
  , integerKindWidth
  , integerKindWrap
  , targetPointerWidth
  , defaultIntegerKind
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

{-| @IntegerLiteral.Kind — the width and signedness a value carries at run time.

    Two's-complement, as [[architecture/SEMANTICS]] requires. `BigIntKind` is the
    one that has no width: it is exact and unbounded, which is what makes it
    different from every other integer rather than merely wider. -}
data IntegerKind
  = SignedKind !Int
  | UnsignedKind !Int
  | PlatformSigned
  | PlatformUnsigned
  | BigIntKind
  deriving stock (Eq, Ord, Show)

{-| The pointer width this build targets.

    [[architecture/SEMANTICS]] makes `Int` and `UInt` the target's pointer width
    and records it in artifact metadata. Until a target is selectable it is
    sixty-four, in one place, so the day it becomes selectable there is one
    place to change. -}
targetPointerWidth :: Int
targetPointerWidth = 64

{-| The kind a named integer type has, given the target's pointer width.

    `Int` and `UInt` keep their own constructors rather than being written as
    the target's width, because they are distinct types: an implementation for
    `Int` is not an implementation for `Int64`, however wide the target is. -}
integerKindOf :: Text -> Maybe IntegerKind
integerKindOf typeName = case typeName of
  "Int8" -> Just (SignedKind 8)
  "Int16" -> Just (SignedKind 16)
  "Int32" -> Just (SignedKind 32)
  "Int64" -> Just (SignedKind 64)
  "Int128" -> Just (SignedKind 128)
  "Int" -> Just PlatformSigned
  "UInt8" -> Just (UnsignedKind 8)
  "UInt16" -> Just (UnsignedKind 16)
  "UInt32" -> Just (UnsignedKind 32)
  "UInt64" -> Just (UnsignedKind 64)
  "UInt128" -> Just (UnsignedKind 128)
  "UInt" -> Just PlatformUnsigned
  "BigInt" -> Just BigIntKind
  _ -> Nothing

{-| The name a kind answers to, for a diagnostic that has to say which type
    overflowed. -}
integerKindName :: IntegerKind -> Text
integerKindName kind = case kind of
  SignedKind width -> "Int" <> decimalText width
  UnsignedKind width -> "UInt" <> decimalText width
  PlatformSigned -> "Int"
  PlatformUnsigned -> "UInt"
  BigIntKind -> "BigInt"

{-| How many bits a kind has, or nothing for the one that has no bound.

    Every bitwise operation needs this, and `Std.Bits` asking a value for its
    own width is what lets it stop claiming sixty-four. -}
integerKindWidth :: IntegerKind -> Maybe Int
integerKindWidth kind = case kind of
  SignedKind width -> Just width
  UnsignedKind width -> Just width
  PlatformSigned -> Just targetPointerWidth
  PlatformUnsigned -> Just targetPointerWidth
  BigIntKind -> Nothing

{-| Whether a kind admits negative values. -}
integerKindSigned :: IntegerKind -> Bool
integerKindSigned kind = case kind of
  SignedKind _ -> True
  UnsignedKind _ -> False
  PlatformSigned -> True
  PlatformUnsigned -> False
  BigIntKind -> True

{-| Whether a value lies inside a kind's interval.

    This is the check [[architecture/SEMANTICS]] requires of every fixed-width
    arithmetic result: the exact mathematical answer or a typed overflow
    failure, never a silently truncated one. -}
integerKindFits :: IntegerKind -> Integer -> Bool
integerKindFits kind value = case kind of
  SignedKind width -> fitsSigned width value
  UnsignedKind width -> fitsUnsigned width value
  PlatformSigned -> fitsSigned targetPointerWidth value
  PlatformUnsigned -> fitsUnsigned targetPointerWidth value
  BigIntKind -> True

{-| A value reduced into a kind's interval by two's-complement wrapping.

    Used only where wrapping is the defined answer — the bitwise operations,
    where a mask is what the operation means — never to rescue an arithmetic
    result that overflowed. -}
integerKindWrap :: IntegerKind -> Integer -> Integer
integerKindWrap kind value = case kind of
  BigIntKind -> value
  _
    | integerKindSigned kind -> wrapSigned (widthOf kind) value
    | otherwise -> value `mod` (2 ^ widthOf kind)
 where
  widthOf other = maybe targetPointerWidth id (integerKindWidth other)
  wrapSigned width raw =
    let modulus = 2 ^ width :: Integer
        reduced = raw `mod` modulus
     in if reduced >= modulus `div` 2 then reduced - modulus else reduced

{-| The kind two operands share.

    The language admits no implicit numeric conversion, so in a program that
    type-checks both operands of an arithmetic operator have the *same* type.
    When the runtime sees two different kinds, one of them therefore came from a
    literal the checker resolved to the other — an unsuffixed `200` written
    where a `UInt8` was wanted carries the default kind because nothing in the
    literal said otherwise.

    So the specific kind wins over the default one, and any width wins over
    `BigInt`. This is exact rather than a guess: it is only reached for a
    program the checker already agreed about. -}
integerKindMeet :: IntegerKind -> IntegerKind -> IntegerKind
integerKindMeet left right
  | left == right = left
  | otherwise = case (left, right) of
      (BigIntKind, other) -> other
      (other, BigIntKind) -> other
      (candidate, other)
        | candidate == defaultIntegerKind -> other
        | other == defaultIntegerKind -> candidate
        | otherwise -> candidate

{-| The kind an integer has when nothing said otherwise: platform `Int`.

    Kept here beside the meet that consults it, so the one place that decides
    what "nothing said otherwise" means is the one place that acts on it. -}
defaultIntegerKind :: IntegerKind
defaultIntegerKind = PlatformSigned

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
