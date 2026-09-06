{-| @Test.Eval.ArithmeticSpec — evaluation of operators, precedence, float arithmetic, and bit-width limits -}
module Pudu.Eval.ArithmeticSpec
  ( arithmeticProperties
  , testArithmetic
  , testIntegerWidths
  ) where

import Test.QuickCheck (Property, conjoin, counterexample, (===))

import Pudu.Eval.Common (codesOf, evaluate, runProgram)

arithmeticProperties :: [(String, IO Property)]
arithmeticProperties =
  [ ("arithmetic and comparison follow declared operators", testArithmetic)
  , ("fixed-width integers keep their width at run time", testIntegerWidths)
  ]

testArithmetic :: IO Property
testArithmetic = do
  sums <- evaluate "1 + 2 * 3"
  precedence <- evaluate "(1 + 2) * 3"
  division <- evaluate "7 / 2"
  remainder <- evaluate "7 % 2"
  comparison <- evaluate "1 < 2 && 3 >= 3"
  concatenation <- evaluate "\"pu\" + \"du\""
  negation <- evaluate "-(2 + 3)"
  newlineChar <- evaluate "'\\n'"
  quotedText <- evaluate "\"a\\nb\""
  leftShift <- evaluate "1 << 4"
  rightShift <- evaluate "64 >> 2"
  bitwiseXor <- evaluate "6 ^ 3"
  bitwiseOr <- evaluate "1 | 2"
  bitwiseAnd <- evaluate "6 & 3"
  bitwiseNot <- evaluate "~0"
  negatedDecimal <- evaluate "-1.50d"
  negatedDecimalAgrees <- evaluate "-1.50d == 0.00d - 1.50d"
  doublyNegatedDecimal <- evaluate "-(-1.50d) == 1.50d"
  suffixedBase <- evaluate "0xffu8"
  signedBoundary <- evaluate "-128i8"
  roundedFloat32Literal <- evaluate "16777217.0f32 == 16777216.0f32"
  roundedFloat32Sum <- evaluate "16777216.0f32 + 1.0f32 == 16777216.0f32"
  retainedFloat64Sum <- evaluate "16777216.0f64 + 1.0f64 == 16777217.0f64"
  negativeFloatZero <- evaluate "-0.0f32"
  floatRangeMatch <- evaluate
    "match 1.5f32 { case 1.0f32..2.0f32 => true case _ => false }"
  pure $ conjoin
    [ sums === "7"
    , precedence === "9"
    , division === "3"
    , remainder === "1"
    , comparison === "true"
    , concatenation === "\"pudu\""
    , negation === "-5"
    , counterexample "a control character is escaped when shown"
        (newlineChar === "'\\n'")
    , quotedText === "\"a\\nb\""
    , counterexample "left shift moves bits left" (leftShift === "16")
    , counterexample "right shift moves bits right" (rightShift === "16")
    , counterexample "xor sets bits in one operand only" (bitwiseXor === "5")
    , counterexample "bitwise or unions bits" (bitwiseOr === "3")
    , counterexample "bitwise and masks bits" (bitwiseAnd === "2")
    , counterexample "bitwise and masks bits" (bitwiseNot === "-1")
    , counterexample "integer suffixes do not alter the runtime value" (suffixedBase === "255")
    , counterexample "signed boundaries retain their mathematical value" (signedBoundary === "-128")
    , counterexample "a Float32 literal rounds to binary32" (roundedFloat32Literal === "true")
    , counterexample "Float32 arithmetic rounds every result" (roundedFloat32Sum === "true")
    , counterexample "Float64 arithmetic retains binary64 precision" (retainedFloat64Sum === "true")
    , counterexample "unary minus preserves negative floating zero" (negativeFloatZero === "-0.0")
    , counterexample "a decimal literal may be negative" (negatedDecimal === "-1.50")
    , counterexample "and equals what subtracting it gives" (negatedDecimalAgrees === "true")
    , counterexample "negating twice answers the original" (doublyNegatedDecimal === "true")
    , counterexample "Float32 range patterns retain their width" (floatRangeMatch === "true")
    ]

testIntegerWidths :: IO Property
testIntegerWidths = do
  complemented <- evaluate "~0u8"
  overflowed <- codesOf "255u8 + 1u8"
  wrapped <- evaluate "255u8 &+ 1u8"
  saturatedHigh <- evaluate "250u8 +| 10u8"
  saturatedLow <- evaluate "0u8 -| 5u8"
  logicalShift <- evaluate "200u8 >> 1"
  arithmeticShift <- evaluate "(0 - 100i8) >> 1"
  wideShift <- codesOf "1u8 << 9"
  negativeShift <- codesOf "1u8 << (0 - 1)"
  annotated <- runProgram [] ["let value: UInt8 = 200"] "value &+ 100u8"
  plainStaysPlain <- evaluate "2000000 + 1"
  fits <- evaluate "convertInteger[UInt8](65)"
  doesNot <- evaluate "convertInteger[UInt8](300)"
  negative <- evaluate "convertInteger[UInt8](0 - 1)"
  widened <- evaluate "convertInteger[Int](200u8)"
  pure $ conjoin
    [ counterexample "complement is taken over the type's width" (complemented === "255")
    , counterexample "checked addition reports overflow" (overflowed === ["E7005"])
    , counterexample "wrapping addition wraps" (wrapped === "0")
    , counterexample "saturating addition stops at the top" (saturatedHigh === "255")
    , counterexample "saturating subtraction stops at nought" (saturatedLow === "0")
    , counterexample "an unsigned shift right brings in noughts" (logicalShift === "100")
    , counterexample "a signed shift right keeps the sign" (arithmeticShift === "-50")
    , counterexample "a shift by the width has no answer" (wideShift === ["E7004"])
    , counterexample "a negative shift count has no answer" (negativeShift === ["E7004"])
    , counterexample "an annotated literal takes its annotated width"
        (annotated === "44")
    , counterexample "a plain integer is unaffected" (plainStaysPlain === "2000001")
    , counterexample "a conversion that fits answers with the value" (fits === "Some(65)")
    , counterexample "a conversion that does not fit answers with nothing" (doesNot === "None")
    , counterexample "a negative value does not fit an unsigned type" (negative === "None")
    , counterexample "widening always fits" (widened === "Some(200)")
    ]
