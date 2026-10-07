{-| @Test.Eval.ArithmeticSpec — evaluation of operators, precedence, float arithmetic, and bit-width limits -}
module Pudu.Eval.ArithmeticSpec
  ( arithmeticProperties
  , testArithmetic
  , testIntegerWidths
  , testTupleOrdering
  ) where

import Test.QuickCheck (Property, conjoin, counterexample, (===))
import qualified Data.Text as Text

import Pudu.Compiler.Program.Common (runEntry)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticMessage, diagnosticSpan)
import Pudu.Eval (EvalOutcome (..), runWithEffects)
import Pudu.Eval.Common (codesOf, codesOfConstant, evaluate, outcomeOf, runProgram)
import Pudu.Eval.Operator (combine)
import Pudu.Eval.Value (Value (BoolValue, TupleValue, UnitValue))
import Pudu.Source (SourceName (SourceName), emptySpan, newSource, spanStart, spanEnd, unOffset)

arithmeticProperties :: [(String, IO Property)]
arithmeticProperties =
  [ ("arithmetic and comparison follow declared operators", testArithmetic)
  , ("fixed-width integers keep their width at run time", testIntegerWidths)
  , ("tuple relations follow lexicographic value ordering", testTupleOrdering)
  ]

testTupleOrdering :: IO Property
testTupleOrdering = do
  let cases =
        [ ("second field", "(1, 2) < (1, 3)", "true")
        , ("first field priority", "(1, 99) < (2, 0)", "true")
        , ("reverse less", "(1, 3) < (1, 2)", "false")
        , ("reverse greater", "(1, 3) > (1, 2)", "true")
        , ("strict less equality", "(1, 2) < (1, 2)", "false")
        , ("strict greater equality", "(1, 2) > (1, 2)", "false")
        , ("inclusive less equality", "(1, 2) <= (1, 2)", "true")
        , ("inclusive greater equality", "(1, 2) >= (1, 2)", "true")
        , ("inclusive less refusal", "(2, 0) <= (1, 99)", "false")
        , ("inclusive greater refusal", "(1, 99) >= (2, 0)", "false")
        , ("nested tuples", "((1, 2), 9) < ((1, 3), 0)", "true")
        , ("aggregate prefix", "([1], 9) < ([1, 0], 0)", "true")
        , ("text tie", "(1, \"a\") < (1, \"b\")", "true")
        , ("fixed-width fields", "(1u8, 2i16) < (1u8, 3i16)", "true")
        , ("finite floating fields", "(1.0f32, 2.0f64) < (1.0f32, 3.0f64)", "true")
        , ("Decimal scales", "(1.0d, 2) < (1.00d, 3)", "true")
        , ("unchanged equality", "(1.0d, 2) == (1.00d, 2)", "true")
        , ("unchanged inequality", "(1.0d, 2) != (1.00d, 3)", "true")
        ]
      functionExpression = "(0, fn(n: Int) -> Int { n }) < (1, fn(n: Int) -> Int { n })"
      prefixLength = Text.length "module Eval.Spec\nfn __entry() {\n"
  results <- mapM (\(label, expression, expected) -> do
    actual <- evaluate expression
    pure $ counterexample label (actual === expected)) cases
  folded <- codesOfConstant "(1, 2) < (1, 3)"
  functions <- outcomeOf [] [] functionExpression
  tasks <- outcomeOf ["async fn work() -> Int { 1 }"] [] "(0, work()) < (1, work())"
  methods <- codesOf "(0, \"a\".trim) < (1, \"b\".trim)"
  arithmetic <- codesOf "(1, 2) + (3, 4)"
  mismatch <- codesOf "(1, 2) < (1, 2, 3)"
  fieldMismatch <- codesOf "(1, \"a\") < (1, 2)"
  equality <- runProgram [] ["let same = fn(n: Int) -> Int { n }"] "(same, 0) == (same, 0)"
  effects <- runProgram []
    [ "var order = 0"
    , "let before = { order = order * 10 + 1\n(1, 2) } < { order = order * 10 + 2\n(1, 3) }"
    ] "(order, before)"
  fixture <- runEntry "test-fixtures/stdlib/UsesTupleOrdering.pudu"
  source <- newSource (SourceName "tuple-runtime.pudu") "(false, ()) < (true, ())"
  direct <- runWithEffects True (combine (emptySpan source) "<"
    (TupleValue [BoolValue False, UnitValue]) (TupleValue [BoolValue True, UnitValue]))
  let details = [(diagnosticCodeText (diagnosticCode finding), diagnosticMessage finding,
          (unOffset (spanStart (diagnosticSpan finding)), unOffset (spanEnd (diagnosticSpan finding))))
        | finding <- outcomeDiagnostics functions]
  pure $ conjoin (results <>
    [ folded === []
    , details === [("E7001", "cannot apply < to a tuple and a tuple",
        (prefixLength, prefixLength + Text.length functionExpression))]
    , map (diagnosticCodeText . diagnosticCode) (outcomeDiagnostics tasks) === ["E7001"]
    , methods === ["E7001"], arithmetic === ["E7001"]
    , mismatch === ["E3001"], fieldMismatch === ["E3001"]
    , equality === "true", effects === "(12, true)", fixture === Just "0"
    , counterexample "direct operator shares the compiled relation" (outcomeValue direct === Just (BoolValue True))
    ])

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
