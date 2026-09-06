{-| @Test.Type.Check.PrimitiveSpec — primitive types, literals, bit widths, and text methods -}
module Pudu.Type.Check.PrimitiveSpec
  ( acceptsIntegerType
  , integerSuffixTypes
  , integerSuffixes
  , integerTypes
  , primitiveProperties
  , testAnnotations
  , testDecimalType
  , testFloatAlias
  , testFloatLiterals
  , testIntegerLiterals
  , testOperators
  , testTextMethods
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Type.Check.Common
  ( codes
  , codesOfExpression
  , compile
  , diagnosticContract
  , typeOf
  , typeOfIn
  )
import Test.QuickCheck (Property, conjoin, counterexample, (===))

primitiveProperties :: [(String, IO Property)]
primitiveProperties =
  [ ("built-in text methods are typed exactly", testTextMethods)
  , ("literals and operators take their declared types", testOperators)
  , ("integer literals select every width and enforce exact bounds", testIntegerLiterals)
  , ("floating suffixes select honest precision and reject overflow", testFloatLiterals)
  , ("annotations are checked against their value", testAnnotations)
  , ("Float aliases to Float64 at the type level", testFloatAlias)
  , ("Decimal is an ordinary type with exact literals", testDecimalType)
  ]

testOperators :: IO Property
testOperators = do
  arithmetic <- typeOf "1 + 2 * 3"
  comparison <- typeOf "1 < 2"
  logic <- typeOf "true && false"
  text <- typeOf "\"a\" + \"b\""
  float <- typeOf "1.5 * 2.0"
  mixed <- codesOfExpression "1 + true"
  logicMismatch <- codesOfExpression "1 && true"
  pure $ conjoin
    [ arithmetic === "Int"
    , comparison === "Bool"
    , logic === "Bool"
    , text === "Str"
    , float === "Float64"
    , counterexample "mixed operands are rejected" (mixed === ["E3001"])
    , counterexample "a boolean operator requires Bool" (logicMismatch === ["E3001"])
    ]

testIntegerLiterals :: IO Property
testIntegerLiterals = do
  contextual <- traverse acceptsIntegerType integerTypes
  suffixTypes <- traverse typeOf integerSuffixes
  defaulted <- typeOf "1"
  selected <- typeOfIn ["fn run() -> Int8 { 1 }"] "1"
  based <- typeOf "0xffu8"
  signedHigh <- codes ["module M", "fn run() -> Int8 { 127i8 }"]
  signedLow <- codes ["module M", "fn run() -> Int8 { -128i8 }"]
  signedOverflow <- codes ["module M", "fn run() -> Int8 { 128i8 }"]
  signedUnderflow <- codes ["module M", "fn run() -> Int8 { -129i8 }"]
  unsignedHigh <- codes ["module M", "fn run() -> UInt8 { 255u8 }"]
  unsignedOverflow <- codes ["module M", "fn run() -> UInt8 { 256u8 }"]
  unsignedNegative <- codes ["module M", "fn run() -> UInt8 { -1u8 }"]
  contextualOverflow <- codes ["module M", "fn run() -> UInt8 { 256 }"]
  hugeBigInt <- codes
    [ "module M"
    , "fn run() -> BigInt { 1606938044258990275541962092341162602522202993782792835301376 }"
    ]
  hugeDefault <- codes
    [ "module M"
    , "fn run() { 1606938044258990275541962092341162602522202993782792835301376 }"
    ]
  nonInteger <- codes ["module M", "fn run() -> Bool { 1 }"]
  arithmetic <- codes ["module M", "fn run() -> Int8 { 1 + 2 }"]
  let overflowSource = Text.unlines
        [ "module M"
        , "fn run() -> Int8 { 128i8 }"
        ]
  overflowResult <- compile overflowSource
  pure $ conjoin
    [ counterexample "every compiler-wired integer type accepts a fitting literal"
        (contextual === replicate (length integerTypes) [])
    , counterexample "every fixed-width suffix selects its exact type"
        (suffixTypes === integerSuffixTypes)
    , counterexample "an unconstrained literal defaults to Int" (defaulted === "Int")
    , counterexample "context selects Int8 before defaulting" (selected === "Int8")
    , counterexample "a suffix survives a base-prefixed body" (based === "UInt8")
    , signedHigh === []
    , signedLow === []
    , counterexample "signed upper overflow is rejected" (signedOverflow === ["E3018"])
    , counterexample "signed lower overflow is rejected" (signedUnderflow === ["E3018"])
    , unsignedHigh === []
    , counterexample "unsigned upper overflow is rejected" (unsignedOverflow === ["E3018"])
    , counterexample "negative unsigned literals are rejected" (unsignedNegative === ["E3018"])
    , counterexample "contextual literals receive the same fit check"
        (contextualOverflow === ["E3018"])
    , counterexample "BigInt remains unbounded" (hugeBigInt === [])
    , counterexample "a context-free huge literal must still fit default Int"
        (hugeDefault === ["E3018"])
    , counterexample "integer syntax cannot satisfy a non-integer context"
        (nonInteger === ["E3001"])
    , counterexample "operator constraints reach both literals" (arithmetic === [])
    , diagnosticContract overflowSource "128i8" "E3018"
        "integer literal 128 does not fit Int8"
        (Just "choose a wider integer type or change the literal")
        overflowResult
    ]

acceptsIntegerType :: Text -> IO [Text]
acceptsIntegerType name = codes ["module M", "fn run() -> " <> name <> " { 1 }"]

integerTypes :: [Text]
integerTypes =
  [ "Int8", "Int16", "Int32", "Int64", "Int128", "Int"
  , "UInt8", "UInt16", "UInt32", "UInt64", "UInt128", "UInt", "BigInt"
  ]

integerSuffixes :: [Text]
integerSuffixes =
  [ "1i8", "1i16", "1i32", "1i64", "1i128"
  , "1u8", "1u16", "1u32", "1u64", "1u128"
  ]

integerSuffixTypes :: [Text]
integerSuffixTypes =
  [ "Int8", "Int16", "Int32", "Int64", "Int128"
  , "UInt8", "UInt16", "UInt32", "UInt64", "UInt128"
  ]

testFloatLiterals :: IO Property
testFloatLiterals = do
  defaulted <- typeOf "1.0"
  selected32 <- typeOf "1.0f32"
  selected64 <- typeOf "1.0f64"
  exponent32 <- typeOf "1e3f32"
  annotated32 <- codes ["module M", "fn run() -> Float32 { 1.0f32 }"]
  implicitNarrowing <- codes ["module M", "fn run() -> Float32 { 1.0 }"]
  arithmetic32 <- codes ["module M", "fn run() -> Float32 { 1.0f32 + 2.0f32 }"]
  mixedWidths <- codes ["module M", "fn run() -> Float64 { 1.0f32 + 2.0f64 }"]
  finiteMaximum <- codes ["module M", "fn run() -> Float32 { 3.4028235e38f32 }"]
  overflow32 <- codes ["module M", "fn run() -> Float32 { 3.4028236e38f32 }"]
  overflow64 <- codes ["module M", "fn run() -> Float64 { 1e309f64 }"]
  underflow <- codes ["module M", "fn run() -> Float32 { 1e-100f32 }"]
  patternOverflow <- codes
    [ "module M"
    , "fn run(value: Float32) -> Bool {"
    , "  match value {"
    , "    case 3.4028236e38f32 => true"
    , "    case _ => false"
    , "  }"
    , "}"
    ]
  let overflowSource = Text.unlines
        [ "module M"
        , "fn run() -> Float32 { 3.4028236e38f32 }"
        ]
  overflowResult <- compile overflowSource
  pure $ conjoin
    [ counterexample "an unsuffixed float stays Float64" (defaulted === "Float64")
    , counterexample "f32 selects Float32" (selected32 === "Float32")
    , counterexample "f64 selects Float64" (selected64 === "Float64")
    , counterexample "suffixes follow exponent text" (exponent32 === "Float32")
    , annotated32 === []
    , counterexample "context cannot narrow an unsuffixed float"
        (implicitNarrowing === ["E3001"])
    , counterexample "same-width Float32 arithmetic is admitted" (arithmetic32 === [])
    , counterexample "mixed float widths require explicit conversion" (mixedWidths === ["E3001"])
    , counterexample "the binary32 maximum is admitted" (finiteMaximum === [])
    , counterexample "binary32 overflow is rejected" (overflow32 === ["E3019"])
    , counterexample "binary64 overflow is rejected" (overflow64 === ["E3019"])
    , counterexample "underflow rounds rather than overflowing" (underflow === [])
    , counterexample "pattern literals receive the same overflow check"
        (patternOverflow === ["E3019"])
    , diagnosticContract overflowSource "3.4028236e38f32" "E3019"
        "floating literal 3.4028236e38f32 does not fit Float32"
        (Just "choose Float64 or reduce the literal magnitude")
        overflowResult
    ]

testAnnotations :: IO Property
testAnnotations = do
  matching <- codes ["module M", "const VALUE: Int = 1"]
  mismatched <- codes ["module M", "const VALUE: Str = 1"]
  inferred <- typeOfIn ["fn run() -> Int {", "  let value = 2", "  value", "}"] "value"
  pure $ conjoin
    [ matching === []
    , mismatched === ["E3001"]
    , counterexample "an unannotated local takes its initializer's type" (inferred === "Int")
    ]

testFloatAlias :: IO Property
testFloatAlias = do
  floatIsAlias <- typeOfIn ["fn run() -> Float { 3.14 }"] "3.14"
  float64Direct <- typeOfIn ["fn run() -> Float64 { 3.14 }"] "3.14"
  pure $ conjoin
    [ counterexample "Float renders as Float64" (floatIsAlias === "Float64")
    , counterexample "Float64 is itself" (float64Direct === "Float64")
    ]

testDecimalType :: IO Property
testDecimalType = do
  annotated <- codes ["module M", "const VALUE: Decimal = 1.0d"]
  parameter <- codes ["module M", "fn run(amount: Decimal) -> Int { 1 }"]
  result <- codes ["module M", "fn run() -> Decimal { 1.0d }"]
  field <- codes ["module M", "type Money = { amount: Decimal }"]
  bothPositions <- codes ["module M", "fn run(amount: Decimal) -> Decimal { amount }"]
  ownDeclaration <- codes
    [ "module M"
    , "type Decimal = { units: Int }"
    , "fn run(amount: Decimal) -> Int { amount.units }"
    ]
  literalType <- typeOf "1.50d"
  wholeLiteral <- typeOf "3d"
  exponentLiteral <- typeOf "1e6d"
  noImplicitFloat <- codesOfExpression "1.5d + 1.5"
  noImplicitInt <- codesOfExpression "1.5d + 1"
  supported <- codes ["module M", "fn run(amount: Float64) -> Float64 { amount }"]
  pure $ conjoin
    [ counterexample "an annotation is ordinary" (annotated === [])
    , counterexample "a parameter is ordinary" (parameter === [])
    , counterexample "a result is ordinary" (result === [])
    , counterexample "a field is ordinary" (field === [])
    , counterexample "both positions are ordinary" (bothPositions === [])
    , counterexample "a module may still declare its own" (ownDeclaration === [])
    , counterexample "a suffixed literal is a Decimal" (literalType === "Decimal")
    , counterexample "a whole literal may be a Decimal" (wholeLiteral === "Decimal")
    , counterexample "an exponent stays exact" (exponentLiteral === "Decimal")
    , counterexample "there is no implicit conversion from a float"
        (noImplicitFloat === ["E3001"])
    , counterexample "there is no implicit conversion from an integer"
        (noImplicitInt === ["E3001"])
    , counterexample "the other numeric types are unaffected" (supported === [])
    ]

testTextMethods :: IO Property
testTextMethods = do
  lengthType <- typeOf "\"abc\".length()"
  charType <- typeOf "\"abc\".charAt(0)"
  sliceType <- typeOf "\"abc\".slice(0, 2)"
  splitType <- typeOf "\"a,b\".split(\",\")"
  charsType <- typeOf "\"ab\".chars()"
  emptyType <- typeOf "\"\".isEmpty()"
  unknown <- codesOfExpression "\"abc\".shout()"
  badArgument <- codesOfExpression "\"abc\".charAt(\"x\")"
  pure $ conjoin
    [ counterexample "length answers an integer" (lengthType === "Int")
    , counterexample "charAt answers a character" (charType === "Char")
    , counterexample "slice answers text" (sliceType === "Str")
    , counterexample "split answers an array of text" (splitType === "Array[Str]")
    , counterexample "chars answers an array of characters" (charsType === "Array[Char]")
    , counterexample "isEmpty answers a boolean" (emptyType === "Bool")
    , counterexample "an unknown text method is E3005" (unknown === ["E3005"])
    , counterexample "an argument is checked" (badArgument === ["E3001"])
    ]
