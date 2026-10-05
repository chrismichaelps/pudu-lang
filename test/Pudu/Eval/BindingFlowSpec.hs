{-| @Test.Eval.BindingFlowSpec — evaluation of lexical bindings, control flow, branching, and loops -}
module Pudu.Eval.BindingFlowSpec
  ( bindingFlowProperties
  , testBindings
  , testBranching
  , testLoops
  , testPureCalls
  , testUnwindFrameCleanup
  ) where

import Test.QuickCheck (Property, conjoin, counterexample, (===))

import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import Data.Maybe (isJust)
import Data.Text (Text)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (diagnosticCodeText, diagnosticCode, diagnosticHelp, diagnosticMessage, diagnosticSpan)
import Pudu.Eval (EvalOutcome (..), callClosure, runWithEffects)
import Pudu.Eval.Common (codesOfConstant, evaluate, evaluateStatements, evaluateWith, outcomeOf, runProgram)
import Pudu.Eval.Env (Env (..), Evaluator (..), callLimit, lookupName, withFrame, withTally)
import Pudu.Eval.Loop.Kernel (pureLoop)
import Pudu.Eval.Operator (readIndex)
import Pudu.Eval.Value (Captured (..), Closure (..), Frame (..), Value (..), intOf)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..), Declaration (..), Expression (..), Function (..), FunctionBody (..), Module (..), Statement (..) )
import Pudu.Source (Offset, SourceName (..), newSource, spanStart, spanEnd)

bindingFlowProperties :: [(String, IO Property)]
bindingFlowProperties =
  [ ("bindings assignment and blocks evaluate in order", testBindings)
  , ("conditionals and pattern matching select branches", testBranching)
  , ("loops iterate and jumps leave them", testLoops)
  , ("pure loop calls preserve parameters limits and fallback", testPureCalls)
  , ("control unwinds restore lexical frames", testUnwindFrameCleanup)
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
  whileLetDrains <- evaluateStatements
    [ "var countdown = Some(3)"
    , "var total = 0"
    , "while let Some(head) = countdown {"
    , "  total = total + head"
    , "  countdown = if head > 1 { Some(head - 1) } else { None }"
    , "}"
    , "total"
    ]
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
    , counterexample "while let stops at the first non-match" (whileLetDrains === "6")
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
  conditionWrites <- evaluateStatements
    [ "var index = 0", "var total = 0"
    , "while { index = index + 1\n index < 5 } { total = total + index }"
    , "(index, total)"
    ]
  shortCircuit <- evaluateStatements
    [ "var index = 0", "var zero = 0"
    , "while index < 3 && (true || 1 / zero > 0) { index = index + 1 }"
    , "index"
    ]
  overflow <- evaluateStatements
    [ "var value = 255u8", "var index = 0"
    , "while index < 1 { index = index + 1\n value = value + 1u8 }"
    , "value"
    ]
  bounded <- codesOfConstant "{ var count = 0\n while true { count = count + 1 }\n true }"
  indexed <- evaluateStatements
    [ "var values = [10, 20, 30]", "let snapshot = values", "let other = [40, 50, 60]"
    , "var index = 0", "var reads = 0", "var total = 0"
    , "while index < 2 && (true || values[999] > 0) {"
    , " total = total + { reads = reads * 10 + 1\n values }[{ reads = reads * 10 + 2\n values = other\n index = index + 1\n index }]"
    , "}", "(index, reads, total, snapshot)"
    ]
  indexedCall <- runProgram ["fn pick(values: Array[Int], index: Int) -> Int = values[index]"]
    [ "let values = [3, 5, 7]", "var index = 0", "var total = 0"
    , "while index < 3 { total = total + pick(values, index)\n index = index + 1 }"
    ] "total"
  indexBoundary <- testIndexBoundary
  pure $ conjoin
    [ counted === "10"
    , counterexample "break leaves the loop" (broken === "4")
    , counterexample "for walks a tuple" (iterated === "6")
    , counterexample "the terminating condition commits its writes" (conditionWrites === "(5, 10)")
    , counterexample "short-circuiting skips invalid arithmetic" (shortCircuit === "3")
    , counterexample "pure loops retain checked overflow" (overflow === "failed: E7005")
    , counterexample "pure constant loops retain the step refusal" (bounded === ["E7002"])
    , counterexample "index reads retain receiver order, skipped errors and immutable snapshots"
        (indexed === "(2, 1212, 80, [10, 20, 30])")
    , counterexample "closed bodies retain parameter indexing" (indexedCall === "15")
    , indexBoundary
    ]

testPureCalls :: IO Property
testPureCalls = do
  record <- runProgram
    [ "type Point = { x: Int, y: Int }"
    , "fn step(p: Point, k: Int) -> Point { Point{x: p.x + k, y: p.y - k} }"
    ]
    [ "var p = Point{x: 0, y: 0}", "var index = 0"
    , "while index < 4 { p = step(p, index)\n index = index + 1 }"
    ] "(p.x, p.y)"
  nested <- runProgram
    [ "fn inc(n: Int) -> Int = n + 1"
    , "fn pack(a: Int, b: Int, c: Int) -> Int = a * 100 + b * 10 + c"
    ]
    [ "var value = 0", "var index = 0"
    , "while index < 1 { value = pack(inc(value), inc(1), inc(2))\n index = index + 1 }"
    ] "value"
  ordered <- runProgram
    [ "fn pack(a: Int, b: Int, c: Int) -> Int = a * 100 + b * 10 + c" ]
    [ "var value = 0", "var result = 0", "var index = 0"
    , "while index < 1 {"
    , " result = pack({ value = value + 1\n value }, { value = value + 1\n value }, { value = value + 1\n value })"
    , " index = index + 1", "}"
    ] "(value, result)"
  shorthand <- runProgram
    [ "type Point = { x: Int, y: Int }"
    , "fn build(x: Int, y: Int) -> Point = Point{x, y}"
    ]
    [ "var p = Point{x: 0, y: 0}", "var index = 0"
    , "while index < 2 { p = build(index, index + 1)\n index = index + 1 }"
    ] "(p.x, p.y)"
  empty <- repeated ["fn step() -> Int = 7"] "value + step()"
  larger <- runProgram
    [ "fn inc(n: Int) -> Int = n + 1"
    , "fn pack(a: Int, b: Int, c: Int, d: Int) -> Int = a * 1000 + b * 100 + c * 10 + d"
    ]
    [ "var value = 0", "var index = 0"
    , "while index < 1 { value = pack(inc(0), inc(1), inc(2), inc(3))\n index = index + 1 }"
    ] "value"
  untaken <- runProgram
    [ "fn step(n: Int, zero: Int) -> Int { if n < 1 { n + 1 } else { n / zero } }" ]
    [ "var value = 0", "var zero = 0"
    , "while value < 1 { value = step(value, zero) }"
    ] "value"
  escaped <- runProgram ["fn select(n: Int) -> fn() -> Str = n.toText"]
    [ "var render = select(0)", "var index = 0"
    , "while index < 3 { render = select(index)\n index = index + 1 }"
    ] "render()"
  free <- repeated
    [ "const OFFSET = 7", "fn shift(n: Int) -> Int = n + OFFSET" ] "shift(value)"
  defaulted <- repeated
    [ "fn shift(n: Int, amount: Int = 7) -> Int = n + amount" ] "shift(value)"
  declared <- repeated
    [ "fn shift(n: Int) -> Int { let amount = 7\n n + amount }" ] "shift(value)"
  callback <- repeated
    [ "fn apply(f: fn(Int) -> Int, n: Int) -> Int = f(n)"
    , "fn shift(n: Int) -> Int = n + 7"
    ] "apply(shift, value)"
  recursive <- repeated
    [ "fn walk(n: Int) -> Int { if n < 1 { 0 } else { walk(n - 1) + 1 } }" ]
    "value + walk(3)"
  local <- runProgram []
    [ "var shift: fn(Int) -> Int = fn(n: Int) -> Int => n + 1"
    , "var value = 0", "var index = 0"
    , "while index < 3 { value = shift(value)\n shift = fn(n: Int) -> Int => n + 10\n index = index + 1 }"
    ] "value"
  shadow <- runProgram ["fn shift(n: Int) -> Int = n + 7"]
    [ "let shift = fn(n: Int) -> Int => n + 1", "var value = 0", "var index = 0"
    , "while index < 3 { value = shift(value)\n index = index + 1 }"
    ] "value"
  lent <- runProgram
    [ "fn bump(n: &mut Int) -> () { *n = *n + 1 }" ]
    [ "var value = 0", "var index = 0"
    , "while index < 3 { bump(&mut value)\n index = index + 1 }"
    ] "value"
  let overflowDeclarations = ["fn bump(n: UInt8) -> UInt8 = n + 1u8"]
      overflowBody = ["var value = 255u8", "var index = 0"
        , "while index < 1 { value = bump(value)\n index = index + 1 }"]
  overflow <- outcomeOf overflowDeclarations overflowBody "value"
  ordinary <- outcomeOf overflowDeclarations
    (take 2 overflowBody <> ["while index < 1 { let marker = 0\n value = bump(value)\n index = index + 1 }"]) "value"
  boundary <- testPureCallBoundary
  pure $ conjoin
    [ counterexample "closed record bodies retain both fields" (record === "(6, -6)")
    , counterexample "nested arguments finish before parameter installation" (nested === "123")
    , counterexample "arguments retain left-to-right writes" (ordered === "(3, 123)")
    , counterexample "record shorthand uses function parameters" (shorthand === "(1, 2)")
    , counterexample "zero parameters need no scratch" (empty === "21")
    , counterexample "the general arity path retains nested argument values" (larger === "1234")
    , counterexample "closed-body branches skip failing arithmetic" (untaken === "1")
    , counterexample "a returned bound member owns its receiver after scratch cleanup" (escaped === "\"2\"")
    , counterexample "free values retain lexical dispatch" (free === "21")
    , counterexample "defaulted functions retain ordinary binding" (defaulted === "21")
    , counterexample "body declarations retain ordinary scope" (declared === "21")
    , counterexample "callback bodies retain ordinary dispatch" (callback === "21")
    , counterexample "recursive bodies retain ordinary depth" (recursive === "9")
    , counterexample "local function replacement is observed" (local === "21")
    , counterexample "a local callee shadows its module function" (shadow === "3")
    , counterexample "exclusive arguments write their original place" (lent === "3")
    , counterexample "closed-body overflow refuses" (outcomeValue overflow === Nothing)
    , counterexample "closed-body overflow keeps E7005"
        (map (diagnosticCodeText . diagnosticCode) (outcomeDiagnostics overflow) === ["E7005"])
    , counterexample "overflow retains ordinary code message help and source offsets"
        (diagnosticIdentity overflow === diagnosticIdentity ordinary)
    , boundary
    ]
 where
  repeated declarations expression = runProgram declarations
    [ "var value = 0", "var index = 0"
    , "while index < 3 { value = " <> expression <> "\n index = index + 1 }"
    ] "value"

diagnosticIdentity :: EvalOutcome -> [(Text, Text, Maybe Text, Offset, Offset)]
diagnosticIdentity outcome =
  [ (diagnosticCodeText (diagnosticCode diagnostic), diagnosticMessage diagnostic
    , diagnosticHelp diagnostic, spanStart (diagnosticSpan diagnostic)
    , spanEnd (diagnosticSpan diagnostic))
  | diagnostic <- outcomeDiagnostics outcome
  ]

testIndexBoundary :: IO Property
testIndexBoundary = do
  source <- newSource (SourceName "pure-index-boundary.pudu")
    "module Boundary\nfn probe(values: Array[Int]) { var turns = 0\n var index = 0\n while turns < 1 { index = values[index]\n turns = turns + 1 } }"
  compiled <- runCompile source
  case compileModule compiled of
    Just parsed
      | [entry] <- [value | Located _ (FunctionDeclaration value) <- moduleDeclarations parsed]
      , Just (Located _ (BlockBody (Located _ Block{blockResult = Just
          (Located loopSpan (WhileExpression _ condition body))}))) <- functionBody entry
      , Located _ Block{blockStatements = [Located _ (ExpressionStatement
          (Located _ (BinaryExpression _ "=" (Located indexSpan IndexExpression{}))))]} <- body -> do
          let values = ArrayValue (Seq.singleton (intOf 7))
              probe index = withFrame [("values", values), ("turns", intOf 0), ("index", index)] $ do
                planned <- pureLoop loopSpan condition body
                case planned of
                  Nothing -> pure (BoolValue False)
                  Just code -> code >> do
                    result <- lookupName "index"
                    turns <- lookupName "turns"
                    pure (BoolValue (result == Just (intOf 7) && turns == Just (intOf 1)))
          accepted <- runWithEffects True (probe (intOf 0))
          refused <- runWithEffects True (probe (intOf 1))
          ordinary <- runWithEffects True (readIndex indexSpan values (intOf 1))
          pure $ conjoin
            [ counterexample "indexed loops actually use the complete kernel"
                (outcomeValue accepted === Just (BoolValue True))
            , counterexample "out-of-bounds kernel indexing refuses" (outcomeValue refused === Nothing)
            , counterexample "index refusal retains the exact ordinary diagnostic"
                (outcomeDiagnostics refused === outcomeDiagnostics ordinary)
            ]
    _ -> pure (counterexample "index boundary fixture did not compile to the expected AST" False)

testPureCallBoundary :: IO Property
testPureCallBoundary = do
  source <- newSource (SourceName "pure-loop-boundary.pudu")
    "module Boundary\nfn bump(n: Int) -> Int = n + 1\nfn main() { var index = 0\n while index < 1 { index = bump(index)\n index = index } }"
  compiled <- runCompile source
  case compileModule compiled of
    Just parsed
      | [function, entry] <- [value | Located _ (FunctionDeclaration value) <- moduleDeclarations parsed]
      , Just (Located _ (BlockBody (Located _ Block{blockResult = Just
          (Located loopSpan (WhileExpression _ condition body))}))) <- functionBody entry
      , Located _ Block{blockStatements = [Located _ (ExpressionStatement
          (Located _ (BinaryExpression _ "=" (Located callSpan (CallExpression _ _)))))]} <- body -> do
          let closure = Closure "bump" function Nothing (Just (Captured [] 0)) [] Nothing
              modules = Map.singleton "bump" (FunctionValue closure)
              atDepth depth (Evaluator action) = Evaluator $ \env -> action env
                { envDepth = depth, envFrames = [MapFrame modules], envModuleDepth = 1 }
              loop depth = atDepth depth $ withFrame [("index", intOf 0)] $ do
                planned <- pureLoop loopSpan condition body
                case planned of
                  Nothing -> pure (BoolValue False)
                  Just code -> do
                    (_, counts) <- withTally code
                    pure (BoolValue (Map.lookup "closure call" counts == Just 1))
          accepted <- runWithEffects True (loop callLimit)
          refused <- runWithEffects True (loop (callLimit + 1))
          ordinary <- runWithEffects True $ atDepth (callLimit + 1)
            (callClosure closure [intOf 0] (Just callSpan))
          pure $ conjoin
            [ counterexample "kernel admission and boundary tally are exercised"
                (outcomeValue accepted === Just (BoolValue True))
            , counterexample "a call one past the depth boundary refuses"
                (isJust (outcomeValue refused) === False)
            , counterexample "depth refusal keeps E7002"
                (map (diagnosticCodeText . diagnosticCode) (outcomeDiagnostics refused) === ["E7002"])
            , counterexample "depth refusal has the same structured diagnostic"
                (outcomeDiagnostics refused === outcomeDiagnostics ordinary)
            ]
    _ -> pure (counterexample "closed loop boundary fixture did not compile to the expected AST" False)
