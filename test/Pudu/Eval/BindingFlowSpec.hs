{-| @Test.Eval.BindingFlowSpec — evaluation of lexical bindings, control flow, branching, and loops -}
module Pudu.Eval.BindingFlowSpec
  ( bindingFlowProperties
  , testBindings
  , testBranching
  , testLoops
  , testUnwindFrameCleanup
  ) where

import Test.QuickCheck (Property, conjoin, counterexample, (===))

import Pudu.Eval.Common (evaluate, evaluateStatements, evaluateWith)

bindingFlowProperties :: [(String, IO Property)]
bindingFlowProperties =
  [ ("bindings assignment and blocks evaluate in order", testBindings)
  , ("conditionals and pattern matching select branches", testBranching)
  , ("loops iterate and jumps leave them", testLoops)
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
  pure $ conjoin
    [ counted === "10"
    , counterexample "break leaves the loop" (broken === "4")
    , counterexample "for walks a tuple" (iterated === "6")
    ]
