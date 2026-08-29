module Pudu.EvalSpec (evalProperties) where

import Control.Monad (when)
import Data.Text (Text)
import System.Directory (doesFileExist, getTemporaryDirectory, removeFile)
import System.IO (hClose, openTempFile)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateEntryPoint)
import Pudu.Eval.Value (renderValue)
import Pudu.Source (SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

evalProperties :: [(String, IO Property)]
evalProperties =
  [ ("arithmetic and comparison follow declared operators", testArithmetic)
  , ("bindings assignment and blocks evaluate in order", testBindings)
  , ("functions defaults and recursion evaluate", testFunctions)
  , ("conditionals and pattern matching select branches", testBranching)
  , ("loops iterate and jumps leave them", testLoops)
  , ("control unwinds restore lexical frames", testUnwindFrameCleanup)
  , ("sum and record values construct and destructure", testData)
  , ("runtime failures report exact diagnostics", testFailures)
  , ("async calls stay cold until an async entry awaits them", testAsync)
  , ("borrowing and dereferencing read the same value", testBorrowing)
  , ("unsafe regions evaluate their block", testUnsafeRegions)
  , ("structured scopes join every task they start", testScopes)
  , ("built-in text methods answer with new values", testTextMethods)
  , ("function literals capture the environment they were written in", testClosures)
  , ("array concatenation joins two arrays", testArrayConcat)
  , ("maps and sets keep their contents in key order", testKeyed)
  , ("effects answer with a result and are refused at compile time", testEffects)
  , ("interpolated strings render their holes", testInterpolation)
  , ("calendar time and subprocesses answer with results", testClock)
  , ("fixed-width integers keep their width at run time", testIntegerWidths)
  , ("implementations reach built-in types", testBuiltinImpls)
  ]

testScopes :: IO Property
testScopes = do
  awaitedChild <- evaluateAsyncWith
    [ "async fn work(n: Int) -> Result[Int, Str] { Ok(n * 2) }" ]
    "async with scope { let first = work(5).await\n Ok(first) }"
  unawaitedChild <- evaluateAsyncWith
    [ "async fn work(n: Int) -> Result[Int, Str] { Ok(n * 2) }" ]
    "async with scope { work(3)\n Ok(1) }"
  failingChild <- evaluateAsyncWith
    [ "async fn failing() -> Result[Int, Str] { Err(\"child failed\") }" ]
    "async with scope { failing()\n Ok(1) }"
  earliestFailure <- evaluateAsyncWith
    [ "async fn first() -> Result[Int, Str] { Err(\"first\") }"
    , "async fn second() -> Result[Int, Str] { Err(\"second\") }"
    ]
    "async with scope { first()\n second()\n Ok(1) }"
  pure $ conjoin
    [ counterexample "a scope yields its block's value" (awaitedChild === "10")
    , counterexample "an unawaited child still runs before the scope yields"
        (unawaitedChild === "1")
    , counterexample "a child's failure leaves the scope"
        (failingChild === "Err(\"child failed\")")
    , counterexample "the earliest failing child supplies the failure"
        (earliestFailure === "Err(\"first\")")
    ]

testUnsafeRegions :: IO Property
testUnsafeRegions = do
  blanket <- evaluateWith ["unsafe fn raw() -> Int { 42 }"] "unsafe { raw() }"
  named <- evaluateWith ["unsafe(raw) fn ptr() -> Int { 7 }"] "unsafe(raw) { ptr() * 2 }"
  nested <- evaluateWith
    [ "unsafe fn inner() -> Int { 3 }"
    , "unsafe fn outer() -> Int { inner() + 1 }"
    ]
    "unsafe { outer() }"
  pure $ conjoin
    [ counterexample "a region yields its block's value" (blanket === "42")
    , counterexample "a named region evaluates the same" (named === "14")
    , counterexample "an unsafe function may call another" (nested === "4")
    ]

testBorrowing :: IO Property
testBorrowing = do
  readThrough <- evaluateStatements
    [ "let value = 7"
    , "let borrowed = &value"
    , "*borrowed"
    ]
  fieldThrough <- evaluateWith
    [ "type User = { name: Str }" ]
    "(*(&User{name: \"ada\"})).name"
  selfDeref <- evaluateWith
    [ "type User = { name: Str }"
    , "trait Clone {"
    , "  fn duplicate(self: &Self) -> Self"
    , "}"
    , "impl Clone for User {"
    , "  fn duplicate(self: &Self) -> Self { *self }"
    , "}"
    ]
    "User{name: \"ada\"}.duplicate().name"
  pure $ conjoin
    [ counterexample "a dereference reads the borrowed value" (readThrough === "7")
    , counterexample "a field is reached through a dereference" (fieldThrough === "\"ada\"")
    , counterexample "&Self dereferences to the receiver" (selfDeref === "\"ada\"")
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
    , counterexample "complement of zero is negative one" (bitwiseNot === "-1")
    , counterexample "integer suffixes do not alter the runtime value" (suffixedBase === "255")
    , counterexample "signed boundaries retain their mathematical value" (signedBoundary === "-128")
    , counterexample "a Float32 literal rounds to binary32" (roundedFloat32Literal === "true")
    , counterexample "Float32 arithmetic rounds every result" (roundedFloat32Sum === "true")
    , counterexample "Float64 arithmetic retains binary64 precision" (retainedFloat64Sum === "true")
    , counterexample "unary minus preserves negative floating zero" (negativeFloatZero === "-0.0")
    , counterexample "Float32 range patterns retain their width" (floatRangeMatch === "true")
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

testUnwindFrameCleanup :: IO Property
testUnwindFrameCleanup = do
  broken <- evaluateWith
    [ "fn leaveLoop() -> Int {"
    , "  loop {"
    , "    { let source = 99\n break 7 }"
    , "  }"
    , "}"
    , "fn caller() -> Int {"
    , "  let source = 5"
    , "  let result = leaveLoop()"
    , "  source + result"
    , "}"
    ]
    "caller()"
  returned <- evaluateWith
    [ "fn leaveFunction() -> Int {"
    , "  { let source = 99\n return 7 }"
    , "  0"
    , "}"
    , "fn caller() -> Int {"
    , "  let source = 5"
    , "  let result = leaveFunction()"
    , "  source + result"
    , "}"
    ]
    "caller()"
  pure $ conjoin
    [ counterexample "break removes every crossed lexical frame" (broken === "12")
    , counterexample "return removes every crossed lexical frame" (returned === "12")
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
  ifLetPresent <- evaluate
    "if let Some(value) = Some(7) { value * 2 } else { 0 }"
  ifLetAbsent <- evaluateWith
    [ "fn pick(value: Option[Int]) -> Int {"
    , "  if let Some(found) = value { found } else { 0 }"
    , "}"
    ]
    "pick(None)"
  ifLetWithoutElse <- evaluateWith
    [ "fn inspect(value: Option[Int]) -> () {"
    , "  if let Some(found) = value { show(found) }"
    , "}"
    ]
    "inspect(None)"
  ifLetSuccessWithoutElse <- evaluateWith
    [ "fn inspect(value: Option[Int]) -> () {"
    , "  if let Some(found) = value { show(found) }"
    , "}"
    ]
    "inspect(Some(1))"
  ifLetOnce <- evaluateStatements
    [ "var calls = 0"
    , "let result = if let Some(value) = { calls = calls + 1\n Some(calls) } { value } else { 0 }"
    , "(calls, result)"
    ]
  optionTryPresent <- evaluateWith
    [ "fn step(value: Option[Int]) -> Option[Int] {"
    , "  let found = value?"
    , "  Some(found + 1)"
    , "}"
    ]
    "match step(Some(41)) { case Some(n) => n case None => 0 }"
  optionTryAbsent <- evaluateWith
    [ "fn step(value: Option[Int]) -> Option[Int] {"
    , "  let found = value?"
    , "  Some(found + 1)"
    , "}"
    ]
    "match step(None) { case Some(n) => n case None => 7 }"
  optionTryStops <- evaluateWith
    [ "fn step(value: Option[Int]) -> Option[Int] {"
    , "  let found = value?"
    , "  show(found)"
    , "  Some(found)"
    , "}"
    ]
    "match step(None) { case Some(n) => n case None => 7 }"
  letElseBound <- evaluateWith
    [ "fn step(value: Option[Int]) -> Int {"
    , "  let Some(found) = value else { return 0 }"
    , "  found + 1"
    , "}"
    ]
    "step(Some(41))"
  letElseTaken <- evaluateWith
    [ "fn step(value: Option[Int]) -> Int {"
    , "  let Some(found) = value else { return 7 }"
    , "  found"
    , "}"
    ]
    "step(None)"
  letElseOutlives <- evaluateWith
    [ "fn step(value: Option[Int]) -> Int {"
    , "  let Some(found) = value else { return 0 }"
    , "  let doubled = found + found"
    , "  doubled + found"
    , "}"
    ]
    "step(Some(3))"
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
    , counterexample "a successful pattern binds its payload" (ifLetPresent === "14")
    , counterexample "a failed pattern evaluates else" (ifLetAbsent === "0")
    , counterexample "failure without else yields unit" (ifLetWithoutElse === "()")
    , counterexample "success without else also yields unit" (ifLetSuccessWithoutElse === "()")
    , counterexample "the subject evaluates exactly once" (ifLetOnce === "(1, 1)")
    , counterexample "? yields a present payload" (optionTryPresent === "42")
    , counterexample "? returns None from the function" (optionTryAbsent === "7")
    , counterexample "? runs nothing after an absent value" (optionTryStops === "7")
    , counterexample "a matched let else binds onward" (letElseBound === "42")
    , counterexample "an unmatched let else takes the fallback" (letElseTaken === "7")
    , counterexample "a let else binding outlives its statement" (letElseOutlives === "9")
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
  outOfRange <- codesOf "[1, 2][5]"
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

testAsync :: IO Property
testAsync = do
  cold <- evaluateWith ["async fn fetch() -> Int { 42 }"] "fetch()"
  awaited <- evaluateAsyncWith ["async fn fetch() -> Int { 42 }"] "Ok(fetch().await)"
  success <- evaluateAsyncWith
    ["async fn fetch() -> Result[Int, Str] { Ok(42) }"]
    "Ok(fetch().await)"
  failure <- evaluateAsyncWith
    ["async fn fetch() -> Result[Int, Str] { Err(\"stop\") }"]
    "Ok(fetch().await)"
  forward <- evaluateAsyncWith
    [ "async fn run() -> Int { fetch().await }"
    , "async fn fetch() -> Int { 42 }"
    ]
    "Ok(run().await)"
  pure $ conjoin
    [ counterexample "calling async does not run its body" (cold === "<task fetch>")
    , counterexample "await starts a non-failing task" (awaited === "42")
    , counterexample "await unwraps task success" (success === "42")
    , counterexample "await propagates task failure" (failure === "Err(\"stop\")")
    , counterexample "forward async calls run from collected declarations" (forward === "42")
    ]

evaluate :: Text -> IO Text
evaluate expression = evaluateWith [] expression

evaluateStatements :: [Text] -> IO Text
evaluateStatements statements = case reverse statements of
  final : leading -> runProgram [] (reverse leading) final
  [] -> pure "none"

{-| Text is a value: every method answers with a new one, indices count Unicode
    scalars, and an index outside the text is a diagnostic rather than a clamped
    answer that looks correct. -}
{-| A literal is called long after the block that gave its free names meaning
    has ended, so it carries that environment with it. Two literals made from
    one function must not share it. -}
testClosures :: IO Property
testClosures = do
  captured <- evaluateWith
    [ "fn adder(step: Int) -> fn(Int) -> Int { fn(n: Int) -> Int => n + step }"
    ]
    "adder(10)(5)"
  independent <- runProgram
    [ "fn adder(step: Int) -> fn(Int) -> Int { fn(n: Int) -> Int => n + step }"
    ]
    [ "let addTen = adder(10)"
    , "let addOne = adder(1)"
    ]
    "addTen(5) + addOne(5)"
  passed <- evaluateWith
    [ "fn apply(f: fn(Int) -> Int, n: Int) -> Int { f(n) }" ]
    "apply(fn(x) => x * 3, 7)"
  overLocal <- runProgram [] ["let base = 100", "let shift = fn(x: Int) -> Int => x + base"] "shift(1)"
  inMap <- evaluate "[1, 2, 3].map(fn(n) => n * 10)"
  pure $ conjoin
    [ counterexample "a literal keeps the value it closed over" (captured === "15")
    , counterexample "two literals do not share one capture" (independent === "21")
    , counterexample "a literal is an ordinary argument" (passed === "21")
    , counterexample "a literal sees the block it was written in" (overLocal === "101")
    , counterexample "a literal drives a built-in method" (inMap === "[10, 20, 30]")
    ]

{-| Joining is a runtime operation because the structure can do it far better
    than a library loop can. -}
testArrayConcat :: IO Property
testArrayConcat = do
  joined <- evaluate "[1, 2].concat([3, 4])"
  leftEmpty <- evaluate "[].concat([1])"
  rightEmpty <- evaluate "[1].concat([])"
  chained <- evaluate "[1].concat([2]).concat([3])"
  pure $ conjoin
    [ counterexample "two arrays join in order" (joined === "[1, 2, 3, 4]")
    , counterexample "an empty left side is the right side" (leftEmpty === "[1]")
    , counterexample "an empty right side is the left side" (rightEmpty === "[1]")
    , counterexample "joining chains" (chained === "[1, 2, 3]")
    ]

{-| A map and a set keep their contents in key order, which is what makes two
    of them equal when their contents are, however they were built. -}
testKeyed :: IO Property
testKeyed = do
  ordered <- evaluate "mapOf([(\"b\", 2), (\"a\", 1)])"
  replaced <- evaluate "mapOf([(\"a\", 1), (\"a\", 2)])"
  built <- evaluate "mapOf([(\"a\", 1)]).insert(\"b\", 2)"
  sameEitherWay <- evaluate "mapOf([(\"a\", 1), (\"b\", 2)]) == mapOf([(\"b\", 2), (\"a\", 1)])"
  found <- evaluate "mapOf([(\"a\", 1)]).get(\"a\")"
  absent <- evaluate "mapOf([(\"a\", 1)]).get(\"z\")"
  merged <- evaluate "mapOf([(\"a\", 1)]).merge(mapOf([(\"a\", 9)]))"
  deduplicated <- evaluate "setOf([3, 1, 2, 1])"
  joined <- evaluate "setOf([1, 2]).union(setOf([2, 3]))"
  shared <- evaluate "setOf([1, 2, 3]).intersect(setOf([2, 3, 4]))"
  removed <- evaluate "setOf([1, 2, 3]).difference(setOf([2]))"
  unorderable <- codesOf "setOf([fn(x) => x])"
  setLoop <- evaluateStatements
    [ "var total = 0"
    , "for member in setOf([1, 2, 3, 4]) { total = total + member }"
    , "total"
    ]
  mapLoop <- evaluateStatements
    [ "var total = 0"
    , "for pair in mapOf([(\"a\", 1), (\"b\", 2)]) { total = total + pair[1] }"
    , "total"
    ]
  pure $ conjoin
    [ counterexample "entries are kept in key order" (ordered === "{\"a\": 1, \"b\": 2}")
    , counterexample "a later pair replaces an earlier one" (replaced === "{\"a\": 2}")
    , counterexample "insertion keeps the order" (built === "{\"a\": 1, \"b\": 2}")
    , counterexample "two maps with the same entries are equal" (sameEitherWay === "true")
    , counterexample "a present key answers with its value" (found === "Some(1)")
    , counterexample "an absent key answers with nothing" (absent === "None")
    , counterexample "merging lets the second map win" (merged === "{\"a\": 9}")
    , counterexample "a set drops duplicates and orders" (deduplicated === "#{1, 2, 3}")
    , counterexample "union joins" (joined === "#{1, 2, 3}")
    , counterexample "intersection keeps what both have" (shared === "#{2, 3}")
    , counterexample "difference removes what the other has" (removed === "#{1, 3}")
    , counterexample "a value with no order cannot be a member" (unorderable === ["E7008"])
    , counterexample "a set is walked by for, as the grammar says" (setLoop === "10")
    , counterexample "a map is walked as key and value pairs" (mapLoop === "3")
    ]

{-| An effect answers with a `Result` rather than failing the program: the
    language has no exceptions, so a missing file is an outcome a caller
    handles. Compile-time folding is refused every effect, because a constant is
    evaluated while the compiler runs. -}
{-| An interpolated string is concatenation with each hole rendered, so a value
    of any type may appear in one and text keeps its own content rather than
    gaining the quotes an inspection would add. -}
testInterpolation :: IO Property
testInterpolation = do
  plain <- runProgram [] ["let name = \"ada\""] "\"hi {name}\""
  arithmetic <- evaluate "\"sum {1 + 2}\""
  collection <- evaluate "\"list {[1, 2]}\""
  character <- evaluate "\"char {'x'}\""
  several <- runProgram [] ["let a = 1", "let b = 2"] "\"{a} and {b}\""
  onlyHole <- runProgram [] ["let a = 7"] "\"{a}\""
  nestedCall <- evaluate "\"len {[1, 2, 3].length()}\""
  nestedString <- evaluate "\"in {\"q\"}\""
  escaped <- evaluate "\"a\\{b\\}c\""
  pure $ conjoin
    [ counterexample "text keeps its own content" (plain === "\"hi ada\"")
    , counterexample "an expression is evaluated" (arithmetic === "\"sum 3\"")
    , counterexample "a collection renders" (collection === "\"list [1, 2]\"")
    , counterexample "a character keeps its own content" (character === "\"char x\"")
    , counterexample "several holes render in order" (several === "\"1 and 2\"")
    , counterexample "a template may be only a hole" (onlyHole === "\"7\"")
    , counterexample "a hole may call a method" (nestedCall === "\"len 3\"")
    , counterexample "a hole may contain a string" (nestedString === "\"in q\"")
    , counterexample "an escaped brace is not a hole" (escaped === "\"a{b}c\"")
    ]

{-| Calendar time and subprocesses are effects like any other: they answer with
    a result and a compile-time constant may not reach them. A program's non-zero
    status is not a failure of running it — the program ran. -}
testClock :: IO Property
testClock = do
  rendered <- evaluate "formatTime(\"%Y-%m-%d\", 1700000000000, \"utc\")"
  parsed <- evaluate "parseTime(\"%Y-%m-%d\", \"2023-11-14\")"
  malformed <- evaluate "parseTime(\"%Y-%m-%d\", \"not a date\")"
  ticking <- evaluate "now() > 1600000000000"
  ran <- evaluate "runProgram(\"echo\", [\"hi\"], \"\")"
  failed <- evaluate "runProgram(\"sh\", [\"-c\", \"exit 7\"], \"\")"
  missing <- evaluate "runProgram(\"pudu-no-such-program-4c3b\", [], \"\")"
  atCompileTime <- codesOfConstant "now() > 0"
  pure $ conjoin
    [ counterexample "an instant renders with a pattern" (rendered === "Ok(\"2023-11-14\")")
    , counterexample "text reads back as an instant" (parsed === "Ok(1699920000000)")
    , counterexample "text that does not fit reports the pattern"
        (property (Text.isPrefixOf "Err(" malformed))
    , counterexample "the system clock is past 2020" (ticking === "true")
    , counterexample "a program's output is collected" (ran === "Ok((0, \"hi\\n\", \"\"))")
    , counterexample "a non-zero status is an answer, not a failure"
        (property (Text.isPrefixOf "Ok((7," failed))
    , counterexample "a program that cannot be run is a failure"
        (property (Text.isPrefixOf "Err(" missing))
    , counterexample "a constant may not read the clock" (atCompileTime === ["E7009"])
    ]

{-| A value's type says how wide it is, so the value has to agree. Without a
    width at run time `~0u8` answers -1 and `255u8 + 1u8` answers 256, neither
    of which is a value those types have. -}
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

{-| An implementation for a built-in type is reachable at run time. It type
    checked before and then failed, which made every generic helper bounded by a
    trait unusable for the types a program actually holds. -}
testBuiltinImpls :: IO Property
testBuiltinImpls = do
  onInteger <- evaluateWith
    [ "trait Doubling { fn twice(self: &Self) -> Self }"
    , "impl Doubling for Int { fn twice(self: &Self) -> Self { *self + *self } }"
    ]
    "21.twice()"
  onText <- evaluateWith
    [ "trait Shouting { fn shout(self: &Self) -> Str }"
    , "impl Shouting for Str { fn shout(self: &Self) -> Str { *self + \"!\" } }"
    ]
    "\"hi\".shout()"
  onArray <- evaluateWith
    [ "trait Counting { fn twice(self: &Self) -> Int }"
    , "impl Counting for Array { fn twice(self: &Self) -> Int { 2 } }"
    ]
    "[1, 2].twice()"
  builtinStillWins <- evaluate "[1, 2, 3].length()"
  generic <- evaluateWith
    [ "trait Ranking { fn before(self: &Self, other: &Self) -> Bool }"
    , "impl Ranking for Int { fn before(self: &Self, other: &Self) -> Bool { *self < *other } }"
    , "fn smallest[T: Ranking](items: &Array[T]) -> Option[T] {"
    , "  if items.length() == 0 { None } else {"
    , "    var best = items[0]"
    , "    for item in items { if item.before(&best) { best = item } }"
    , "    Some(best)"
    , "  }"
    , "}"
    ]
    "smallest(&[3, 1, 2])"
  pure $ conjoin
    [ counterexample "an implementation for Int is reachable" (onInteger === "42")
    , counterexample "an implementation for Str is reachable" (onText === "\"hi!\"")
    , counterexample "an implementation for Array is reachable" (onArray === "2")
    , counterexample "a built-in method still wins its own name" (builtinStillWins === "3")
    , counterexample "a bounded generic works over a built-in type"
        (generic === "Some(1)")
    ]

{-| The effects, against a real file this machine is willing to give us.

    The path is asked for rather than written down. `/tmp` is one operating
    system's answer and not another's, and a fixed name under it is shared by
    every copy of this suite running on the machine — two developers, or one
    developer twice, would have raced for the same file. `openTempFile` answers
    with a name nothing else holds. -}
testEffects :: IO Property
testEffects = do
  directory <- getTemporaryDirectory
  (path, handle) <- openTempFile directory "pudu-effect-test.txt"
  hClose handle
  let quoted = Text.pack (escapeForSource path)
      absentPath = quoted <> ".absent"
  written <- evaluate ("writeFile(\"" <> quoted <> "\", \"x\")")
  readBack <- evaluate ("readFile(\"" <> quoted <> "\")")
  missing <- evaluate ("readFile(\"" <> absentPath <> "\")")
  present <- evaluate ("fileExists(\"" <> quoted <> "\")")
  absent <- evaluate ("fileExists(\"" <> absentPath <> "\")")
  removed <- evaluate ("removeFile(\"" <> quoted <> "\")")
  ticking <- evaluate "clock() >= 0"
  atCompileTime <- codesOfConstant ("fileExists(\"" <> quoted <> "\")")
  stillThere <- doesFileExist path
  when stillThere (removeFile path)
  pure $ conjoin
    [ counterexample "writing answers with success" (written === "Ok(())")
    , counterexample "reading answers with the contents" (readBack === "Ok(\"x\")")
    , counterexample "a missing file is a failure, not a crash"
        (property (Text.isPrefixOf "Err(" missing))
    , counterexample "a present path is reported" (present === "true")
    , counterexample "an absent path is reported" (absent === "false")
    , counterexample "removing answers with success" (removed === "Ok(())")
    , counterexample "the clock moves forward" (ticking === "true")
    , counterexample "a constant may not reach the world" (atCompileTime === ["E7009"])
    ]

{-| A path as a Pudu string literal.

    A backslash is a path separator on one operating system and an escape in
    every string literal, so a path written into source has to say which it
    means. -}
escapeForSource :: FilePath -> String
escapeForSource = concatMap one
 where
  one character = case character of
    '\\' -> "\\\\"
    '"' -> "\\\""
    _ -> [character]

{-| The diagnostics a module-scope constant produces, which is the compile-time
    evaluation path. -}
codesOfConstant :: Text -> IO [Text]
codesOfConstant expression = do
  source <-
    newSource (SourceName "constant.pudu")
      (Text.unlines ["module M", "const VALUE: Bool = " <> expression])
  result <- runCompile source
  pure (map (diagnosticCodeText . diagnosticCode) (compileDiagnostics result))

testTextMethods :: IO Property
testTextMethods = do
  upper <- evaluate "\"aB\".toUpper()"
  trimmed <- evaluate "\"  x \".trim()"
  split <- evaluate "\"a,b\".split(\",\")"
  chars <- evaluate "\"hi\".chars()"
  charAt <- evaluate "\"héllo\".charAt(1)"
  scalarLength <- evaluate "\"héllo\".length()"
  sliced <- evaluate "\"hello\".slice(1, 3)"
  clamped <- evaluate "\"hi\".slice(0, 99)"
  absent <- evaluate "\"hello\".indexOf(\"zz\")"
  replaced <- evaluate "\"banana\".replace(\"a\", \"o\")"
  reversed <- evaluate "\"abc\".reverse()"
  unchanged <- runProgram [] ["var name = \"a\"", "name.toUpper()"] "name"
  outOfRange <- codesOf "\"hi\".charAt(9)"
  negativeRepeat <- codesOf "\"hi\".repeat(-1)"
  pure $ conjoin
    [ counterexample "case folds" (upper === "\"AB\"")
    , counterexample "whitespace is stripped" (trimmed === "\"x\"")
    , counterexample "split yields the fields" (split === "[\"a\", \"b\"]")
    , counterexample "chars yields characters" (chars === "['h', 'i']")
    , counterexample "indices count scalars, not bytes" (charAt === "'\233'")
    , counterexample "length counts scalars, not bytes" (scalarLength === "5")
    , counterexample "a slice takes the range" (sliced === "\"el\"")
    , counterexample "a slice past the end is the rest" (clamped === "\"hi\"")
    , counterexample "an absent needle answers -1" (absent === "-1")
    , counterexample "replace changes every occurrence" (replaced === "\"bonono\"")
    , counterexample "reverse reverses" (reversed === "\"cba\"")
    , counterexample "the receiver is unchanged" (unchanged === "\"a\"")
    , counterexample "an index outside the text is E7004" (outOfRange === ["E7004"])
    , counterexample "a negative repeat is E7004" (negativeRepeat === ["E7004"])
    ]

evaluateWith :: [Text] -> Text -> IO Text
evaluateWith declarations expression = runProgram declarations [] expression

evaluateAsyncWith :: [Text] -> Text -> IO Text
evaluateAsyncWith declarations expression = do
  outcome <- outcomeOfWithEntry "async fn __entry() -> Result[Int, Str] {" declarations [] expression
  pure (maybe (renderCodes outcome) renderValue (outcomeValue outcome))

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
  outcomeOfWithEntry "fn __entry() {" declarations statements expression

outcomeOfWithEntry :: Text -> [Text] -> [Text] -> Text -> IO EvalOutcome
outcomeOfWithEntry opening declarations statements expression = do
  let buffer =
        Text.unlines
          ( ["module Eval.Spec"]
              <> declarations
              <> [opening]
              <> statements
              <> [expression, "}"]
          )
  source <- newSource (SourceName "eval.pudu") buffer
  result <- runCompile source
  case compileModule result of
    Nothing ->
      pure
        EvalOutcome
          { outcomeValue = Nothing
          , outcomeDiagnostics = compileDiagnostics result
          }
    Just parsed -> evaluateEntryPoint (compileIntegerKinds result) "__entry" parsed

renderCodes :: EvalOutcome -> Text
renderCodes outcome =
  "failed: "
    <> Text.intercalate "," (map (diagnosticCodeText . diagnosticCode) (outcomeDiagnostics outcome))
