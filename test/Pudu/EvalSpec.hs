module Pudu.EvalSpec (evalProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText)
import Pudu.Eval (EvalOutcome (..), evaluateEntryPoint)
import Pudu.Eval.Value (renderValue)
import Pudu.Source (SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

evalProperties :: [(String, IO Property)]
evalProperties =
  [ ("arithmetic and comparison follow declared operators", testArithmetic)
  , ("bindings assignment and blocks evaluate in order", testBindings)
  , ("functions defaults and recursion evaluate", testFunctions)
  , ("conditionals and pattern matching select branches", testBranching)
  , ("loops iterate and jumps leave them", testLoops)
  , ("sum and record values construct and destructure", testData)
  , ("runtime failures report exact diagnostics", testFailures)
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
    , counterexample "complement of zero is negative one" (bitwiseNot === "-1")
    ]

testBindings :: IO Property
testBindings = do
  sequential <- evaluateStatements
    [ "let first = 10"
    , "let second = first * 2"
    , "first + second"
    ]
  mutation <- evaluateStatements
    [ "var total = 0"
    , "total = total + 5"
    , "total = total + 5"
    , "total"
    ]
  shadowing <- evaluateStatements
    [ "let value = 1"
    , "{"
    , "  let value = 2"
    , "  value"
    , "}"
    ]
  pure $ conjoin
    [ sequential === "30"
    , counterexample "assignment writes the existing binding" (mutation === "10")
    , counterexample "an inner block shadows" (shadowing === "2")
    ]

testFunctions :: IO Property
testFunctions = do
  direct <- evaluateWith ["fn double(n: Int) -> Int { n * 2 }"] "double(21)"
  defaulted <- evaluateWith ["fn greet(name: Str, mark: Str = \"!\") -> Str { name + mark }"] "greet(\"pudu\")"
  chained <- evaluateWith
    [ "fn add(a: Int, b: Int) -> Int { a + b }"
    , "fn quadruple(n: Int) -> Int { add(n, n) + add(n, n) }"
    ]
    "quadruple(4)"
  recursive <- evaluateWith
    [ "fn factorial(n: Int) -> Int {"
    , "  if n <= 1 {"
    , "    1"
    , "  } else {"
    , "    n * factorial(n - 1)"
    , "  }"
    , "}"
    ]
    "factorial(6)"
  expressionBody <- evaluateWith ["fn triple(n: Int) -> Int = n * 3"] "triple(5)"
  pure $ conjoin
    [ direct === "42"
    , counterexample "a default fills a missing argument" (defaulted === "\"pudu!\"")
    , chained === "16"
    , recursive === "720"
    , expressionBody === "15"
    ]

testBranching :: IO Property
testBranching = do
  conditional <- evaluate "if 2 > 1 { \"yes\" } else { \"no\" }"
  matched <- evaluate "match 3 { case 1 => \"one\" case 3 => \"three\" case _ => \"other\" }"
  guarded <- evaluateWith [] "match 10 { case n if n > 5 => \"big\" case _ => \"small\" }"
  ranged <- evaluate "match 7 { case 1..5 => \"low\" case 6..=9 => \"high\" case _ => \"out\" }"
  alternation <- evaluate "match 2 { case 1 | 2 => \"either\" case _ => \"other\" }"
  early <- evaluateWith
    [ "fn classify(n: Int) -> Str {"
    , "  if n < 0 {"
    , "    return \"negative\""
    , "  }"
    , "  \"positive\""
    , "}"
    ]
    "classify(0 - 4)"
  pure $ conjoin
    [ conditional === "\"yes\""
    , matched === "\"three\""
    , guarded === "\"big\""
    , ranged === "\"high\""
    , alternation === "\"either\""
    , counterexample "return leaves the function" (early === "\"negative\"")
    ]

testLoops :: IO Property
testLoops = do
  counted <- evaluateStatements
    [ "var total = 0"
    , "var index = 0"
    , "while index < 5 {"
    , "  total = total + index"
    , "  index = index + 1"
    , "}"
    , "total"
    ]
  broken <- evaluateStatements
    [ "var count = 0"
    , "loop {"
    , "  count = count + 1"
    , "  if count > 3 {"
    , "    break"
    , "  }"
    , "}"
    , "count"
    ]
  iterated <- evaluateStatements
    [ "var seen = 0"
    , "for item in (1, 2, 3) {"
    , "  seen = seen + item"
    , "}"
    , "seen"
    ]
  pure $ conjoin
    [ counted === "10"
    , counterexample "break leaves the loop" (broken === "4")
    , counterexample "for walks a tuple" (iterated === "6")
    ]

testData :: IO Property
testData = do
  variant <- evaluateWith
    [ "type Outcome ="
    , "  | Ok(Int)"
    , "  | Err(Str)"
    ]
    "match Ok(3) { case Ok(value) => value * 2 case Err(_) => 0 }"
  qualified <- evaluateWith
    [ "type Outcome ="
    , "  | Ok(Int)"
    , "  | Err(Str)"
    ]
    "match Outcome.Err(\"stop\") { case Ok(_) => \"ok\" case Err(reason) => reason }"
  record <- evaluateWith
    [ "type User = { id: Int, name: Str }" ]
    "User{id: 3, name: \"ada\"}.name"
  shorthand <- runProgram
    [ "type User = { id: Int, name: Str }" ]
    [ "let id = 9", "let name = \"pudu\"" ]
    "User{id, name}.id"
  recordPattern <- evaluateWith
    [ "type User = { id: Int, name: Str }" ]
    "match (User{id: 4, name: \"x\"}) { case User{id} => id * 2 }"
  tuple <- evaluate "(1, \"two\", true)"
  indexed <- evaluate "(10, 20, 30)[1]"
  let propagationProgram =
        [ "fn attempt(flag: Bool) -> Result[Int, Str] {"
        , "  if flag { Ok(1) } else { Err(\"stop\") }"
        , "}"
        , "fn run(flag: Bool) -> Result[Int, Str] {"
        , "  let value = attempt(flag)?"
        , "  Ok(value + 1)"
        , "}"
        ]
  propagation <- evaluateWith propagationProgram "run(true)"
  failure <- evaluateWith propagationProgram "run(false)"
  pure $ conjoin
    [ variant === "6"
    , qualified === "\"stop\""
    , counterexample "a record is built and read" (record === "\"ada\"")
    , counterexample "shorthand takes the binding of the same name" (shorthand === "9")
    , counterexample "a record pattern destructures it" (recordPattern === "8")
    , tuple === "(1, \"two\", true)"
    , indexed === "20"
    , counterexample "? unwraps a success" (propagation === "Ok(2)")
    , counterexample "? returns the failure from its function"
        (failure === "Err(\"stop\")")
    ]

testFailures :: IO Property
testFailures = do
  divisor <- codesOf "1 / 0"
  modulo <- codesOf "1 % 0"
  outOfRange <- codesOf "(1, 2)[5]"
  mismatch <- codesOf "1 + true"
  noArm <- codesOf "match 9 { case 1 => 1 }"
  panic <- codesOf "panic(\"boom\")"
  pure $ conjoin
    [ divisor === ["E7004"]
    , modulo === ["E7004"]
    , outOfRange === ["E7004"]
    , counterexample "typing rejects a mixed operand before evaluation"
        (mismatch === ["E3001"])
    , counterexample "an unmatched value is rejected before it can be evaluated"
        (noArm === ["E5001"])
    , counterexample "panic stops evaluation with E7007"
        (panic === ["E7007"])
    ]

evaluate :: Text -> IO Text
evaluate expression = evaluateWith [] expression

evaluateStatements :: [Text] -> IO Text
evaluateStatements statements = case reverse statements of
  final : leading -> runProgram [] (reverse leading) final
  [] -> pure "none"

evaluateWith :: [Text] -> Text -> IO Text
evaluateWith declarations expression = runProgram declarations [] expression

runProgram :: [Text] -> [Text] -> Text -> IO Text
runProgram declarations statements expression = do
  outcome <- outcomeOf declarations statements expression
  pure (maybe (renderCodes outcome) renderValue (outcomeValue outcome))

codesOf :: Text -> IO [Text]
codesOf expression = do
  outcome <- outcomeOf [] [] expression
  pure (map (diagnosticCodeText . diagnosticCode) (outcomeDiagnostics outcome))

outcomeOf :: [Text] -> [Text] -> Text -> IO EvalOutcome
outcomeOf declarations statements expression = do
  let buffer =
        Text.unlines
          ( ["module Eval.Spec"]
              <> declarations
              <> ["fn __entry() {"]
              <> statements
              <> [expression, "}"]
          )
  source <- newSource (SourceName "eval.pudu") buffer
  let result = runCompile source
  case compileModule result of
    Nothing ->
      pure
        EvalOutcome
          { outcomeValue = Nothing
          , outcomeDiagnostics = compileDiagnostics result
          }
    Just parsed -> pure (evaluateEntryPoint "__entry" parsed)

renderCodes :: EvalOutcome -> Text
renderCodes outcome =
  "failed: "
    <> Text.intercalate "," (map (diagnosticCodeText . diagnosticCode) (outcomeDiagnostics outcome))
