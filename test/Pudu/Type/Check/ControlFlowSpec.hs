{-| @Test.Type.Check.ControlFlowSpec — control flow, branches, loop iteration, and error cascading -}
module Pudu.Type.Check.ControlFlowSpec
  ( controlFlowProperties
  , testControlFlow
  , testExportedSignatures
  , testIterationTypes
  , testNoCascade
  , testPhaseOrder
  , testTry
  ) where

import qualified Data.Text as Text
import Pudu.Type.Check.Common
  ( codes
  , compile
  , diagnosticContract
  )
import Test.QuickCheck (Property, conjoin, counterexample, (===))

controlFlowProperties :: [(String, IO Property)]
controlFlowProperties =
  [ ("control flow unifies its branches", testControlFlow)
  , ("exported signatures must be annotated", testExportedSignatures)
  , ("a type error reports once and does not cascade", testNoCascade)
  , ("an earlier phase's error suppresses type checking", testPhaseOrder)
  , ("? unwraps a Result inside a Result-returning function", testTry)
  , ("a for loop binds at the element type of what it iterates", testIterationTypes)
  ]

testControlFlow :: IO Property
testControlFlow = do
  branches <- codes ["module M", "fn run(flag: Bool) -> Int { if flag { 1 } else { 2 } }"]
  contextualBranches <- codes
    ["module M", "fn run(flag: Bool) -> UInt8 { if flag { 1 } else { 2 } }"]
  contextualMatch <- codes
    [ "module M"
    , "fn run(flag: Bool) -> UInt8 {"
    , "  match flag {"
    , "    case true => 1"
    , "    case false => 2"
    , "  }"
    , "}"
    ]
  mixedBranches <- codes ["module M", "fn run(flag: Bool) -> Int { if flag { 1 } else { \"two\" } }"]
  condition <- codes ["module M", "fn run() -> Int { if 1 { 1 } else { 2 } }"]
  returningMatchArm <- codes
    [ "module M"
    , "fn run(flag: Bool) -> Int {"
    , "  match flag {"
    , "    case true => { return 1 }"
    , "    case false => 2"
    , "  }"
    , "}"
    ]
  returningIfBranch <- codes
    [ "module M"
    , "fn run(flag: Bool) -> Int {"
    , "  if flag { return 1 } else { 2 }"
    , "}"
    ]
  breakingIfBranch <- codes
    [ "module M"
    , "fn run(flag: Bool) -> Int {"
    , "  loop {"
    , "    let found = if flag { break 0 } else { 1 }"
    , "    break found"
    , "  }"
    , "}"
    ]
  continuingIfBranch <- codes
    [ "module M"
    , "fn run(flag: Bool) -> Int {"
    , "  loop {"
    , "    let found = if flag { continue } else { 1 }"
    , "    break found"
    , "  }"
    , "}"
    ]
  let fallthroughSource = Text.unlines
        [ "module M"
        , "fn run(flag: Bool) -> Int {"
        , "  match flag {"
        , "    case true => { let found = 1 }"
        , "    case false => 2"
        , "  }"
        , "}"
        ]
  fallthroughBlock <- compile fallthroughSource
  ifLet <- codes
    [ "module M"
    , "fn run(value: Option[Int]) -> Int {"
    , "  if let Some(found) = value { found } else { 0 }"
    , "}"
    ]
  ifLetBranches <- codes
    [ "module M"
    , "fn run(value: Option[Int]) -> Int {"
    , "  if let Some(found) = value { found } else { \"none\" }"
    , "}"
    ]
  ifLetPattern <- codes
    [ "module M"
    , "fn run(value: Int) -> Int {"
    , "  if let Some(found) = value { found } else { 0 }"
    , "}"
    ]
  ifLetBorrow <- codes
    [ "module M"
    , "fn run(value: &Option[Int]) -> Int {"
    , "  if let Some(found) = value { found } else { 0 }"
    , "}"
    ]
  ifLetWithoutElse <- codes
    [ "module M"
    , "fn run(value: Option[Int]) -> Int {"
    , "  if let Some(found) = value { found }"
    , "}"
    ]
  tryOption <- codes
    [ "module M"
    , "fn run(value: Option[Int]) -> Option[Int] {"
    , "  let found = value?"
    , "  Some(found + 1)"
    , "}"
    ]
  tryOptionInResult <- codes
    [ "module M"
    , "fn run(value: Option[Int]) -> Result[Int, Str] {"
    , "  let found = value?"
    , "  Ok(found)"
    , "}"
    ]
  tryResultInOption <- codes
    [ "module M"
    , "fn run(value: Result[Int, Str]) -> Option[Int] {"
    , "  let found = value?"
    , "  Some(found)"
    , "}"
    ]
  tryOptionInPlain <- codes
    [ "module M"
    , "fn run(value: Option[Int]) -> Int {"
    , "  let found = value?"
    , "  found"
    , "}"
    ]
  letElseTyped <- codes
    [ "module M"
    , "fn run(value: Option[Int]) -> Int {"
    , "  let Some(found) = value else { return 0 }"
    , "  found + 1"
    , "}"
    ]
  letElseFallsThrough <- codes
    [ "module M"
    , "fn run(value: Option[Int]) -> Int {"
    , "  let Some(found) = value else { 0 }"
    , "  found"
    , "}"
    ]
  letElseContinues <- codes
    [ "module M"
    , "fn run(values: Array[Option[Int]]) -> Int {"
    , "  var total = 0"
    , "  for value in values {"
    , "    let Some(found) = value else { continue }"
    , "    total = total + found"
    , "  }"
    , "  total"
    , "}"
    ]
  letElseMismatch <- codes
    [ "module M"
    , "fn run(value: Int) -> Int {"
    , "  let Some(found) = value else { return 0 }"
    , "  found"
    , "}"
    ]
  letElseWildcard <- codes
    [ "module M"
    , "fn run(value: Int) -> Int {"
    , "  let _ = value else { return 0 }"
    , "  value"
    , "}"
    ]
  letElseTuple <- codes
    [ "module M"
    , "fn run(pair: (Int, Int)) -> Int {"
    , "  let (first, second) = pair else { return 0 }"
    , "  first + second"
    , "}"
    ]
  plainLet <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  let found = 1"
    , "  found"
    , "}"
    ]
  propagatingMatch <- codes
    [ "module M"
    , "fn step(value: Result[Int, Str]) -> Result[Int, Str] {"
    , "  match value {"
    , "    case Err(problem) => Err(problem)"
    , "    case Ok(found) => Ok(found + 1)"
    , "  }"
    , "}"
    ]
  propagatingReturn <- codes
    [ "module M"
    , "fn step(value: Result[Int, Str]) -> Result[Int, Str] {"
    , "  match value {"
    , "    case Err(problem) => { return Err(problem) }"
    , "    case Ok(found) => { return Ok(found + 1) }"
    , "  }"
    , "  Err(\"unreachable\")"
    , "}"
    ]
  propagatingOption <- codes
    [ "module M"
    , "fn step(value: Option[Int]) -> Option[Int] {"
    , "  match value {"
    , "    case None => None"
    , "    case Some(found) => Some(found + 1)"
    , "  }"
    , "}"
    ]
  transformingMatch <- codes
    [ "module M"
    , "fn step(value: Result[Int, Str]) -> Result[Int, Str] {"
    , "  match value {"
    , "    case Err(problem) => Err(problem + \"!\")"
    , "    case Ok(found) => Ok(found + 1)"
    , "  }"
    , "}"
    ]
  crossCarrierMatch <- codes
    [ "module M"
    , "fn step(value: Option[Int]) -> Result[Int, Str] {"
    , "  match value {"
    , "    case None => Err(\"absent\")"
    , "    case Some(found) => Ok(found)"
    , "  }"
    , "}"
    ]
  plainCarrierMatch <- codes
    [ "module M"
    , "fn step(value: Result[Int, Str]) -> Int {"
    , "  match value {"
    , "    case Err(_problem) => 0"
    , "    case Ok(found) => found"
    , "  }"
    , "}"
    ]
  whileLetTyped <- codes
    [ "module M"
    , "fn run(start: Option[Int]) -> Int {"
    , "  var cell = start"
    , "  var total = 0"
    , "  while let Some(head) = cell {"
    , "    total = total + head"
    , "    cell = None"
    , "  }"
    , "  total"
    , "}"
    ]
  whileLetScope <- codes
    [ "module M"
    , "fn run(start: Option[Int]) -> Int {"
    , "  while let Some(head) = start { }"
    , "  head"
    , "}"
    ]
  whileLetIrrefutable <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  while let found = 1 { }"
    , "  0"
    , "}"
    ]
  loops <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  var total = 0"
    , "  while total < 3 {"
    , "    total = total + 1"
    , "  }"
    , "  total"
    , "}"
    ]
  returned <- codes
    [ "module M"
    , "fn run(flag: Bool) -> Int {"
    , "  if flag {"
    , "    return \"text\""
    , "  }"
    , "  1"
    , "}"
    ]
  pure $ conjoin
    [ branches === []
    , counterexample "an outer result selects if literal widths" (contextualBranches === [])
    , counterexample "an outer result selects match literal widths" (contextualMatch === [])
    , mixedBranches === ["E3001"]
    , counterexample "a condition must be Bool" (condition === ["E3001"])
    , counterexample "a returning match arm has type Never" (returningMatchArm === [])
    , counterexample "a returning if branch has type Never" (returningIfBranch === [])
    , counterexample "a breaking if branch has type Never" (breakingIfBranch === [])
    , counterexample "a continuing if branch has type Never" (continuingIfBranch === [])
    , diagnosticContract fallthroughSource "2" "E3001"
        "expected (), found Int"
        (Just "change the value, or change the declared type it must match")
        fallthroughBlock
    , counterexample "if let checks and binds a matching payload" (ifLet === [])
    , counterexample "if let branches unify" (ifLetBranches === ["E3001"])
    , counterexample "if let checks its pattern against the subject" (ifLetPattern === ["E3001"])
    , counterexample "if let reads through a borrow like match" (ifLetBorrow === [])
    , counterexample "if let without else has unit type" (ifLetWithoutElse === ["E3001"])
    , counterexample "? unwraps an Option in an Option function" (tryOption === [])
    , counterexample "? on Option needs an Option function" (tryOptionInResult === ["E3001"])
    , counterexample "? on Result needs a Result function" (tryResultInOption === ["E3001"])
    , counterexample "? needs a carrier return type" (tryOptionInPlain === ["E3011"])
    , counterexample "let else binds for the rest of the block" (letElseTyped === [])
    , counterexample "a let else fallback must not fall through"
        (letElseFallsThrough === ["E3036"])
    , counterexample "continue is a diverging fallback" (letElseContinues === [])
    , counterexample "a let else subject must match its pattern"
        (letElseMismatch === ["E3001"])
    , counterexample "let else rejects a wildcard, which cannot fail"
        (letElseWildcard === ["E1057"])
    , counterexample "let else rejects a tuple, which cannot fail"
        (letElseTuple === ["E1057"])
    , counterexample "an ordinary let is untouched" (plainLet === [])
    , counterexample "a pass-through Err arm is a ?" (propagatingMatch === ["W3003"])
    , counterexample "a returned pass-through is the same arm" (propagatingReturn === ["W3003"])
    , counterexample "a pass-through None arm is a ?" (propagatingOption === ["W3003"])
    , counterexample "a transformed failure is a decision" (transformingMatch === [])
    , counterexample "a changed carrier is a decision" (crossCarrierMatch === [])
    , counterexample "a match into a plain result is a decision" (plainCarrierMatch === [])
    , counterexample "while let binds its payload in the body" (whileLetTyped === [])
    , counterexample "a while let binding does not escape its body"
        (whileLetScope === ["E2010"])
    , counterexample "while let rejects a pattern that always matches"
        (whileLetIrrefutable === ["E1058"])
    , loops === []
    , counterexample "return is checked against the declared result"
        (returned === ["E3001"])
    ]

testExportedSignatures :: IO Property
testExportedSignatures = do
  annotated <- codes ["module M", "export fn run(value: Int) -> Int { value }"]
  missingReturn <- codes ["module M", "export fn run(value: Int) { value }"]
  missingParameter <- codes ["module M", "export fn run(value) -> Int { value }"]
  annotatedBinding <- codes ["module M", "export const ANSWER: Int = 42"]
  missingBinding <- codes ["module M", "export const ANSWER = 42"]
  privateInferred <- codes ["module M", "fn run(value) { value }"]
  pure $ conjoin
    [ annotated === []
    , missingReturn === ["E3010"]
    , missingParameter === ["E3010"]
    , annotatedBinding === []
    , counterexample "an exported binding has a body-free interface type" (missingBinding === ["E3010"])
    , counterexample "a private function may infer" (privateInferred === [])
    ]

testNoCascade :: IO Property
testNoCascade = do
  result <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  let wrong: Int = \"text\""
    , "  wrong + wrong + wrong"
    , "}"
    ]
  pure (counterexample "one mistake is reported once" (result === ["E3001"]))

testPhaseOrder :: IO Property
testPhaseOrder = do
  result <- codes ["module M", "fn run() -> Int { missing + 1 }"]
  pure
    ( counterexample "an unresolved name is not also a type error"
        (result === ["E2010"])
    )

testTry :: IO Property
testTry = do
  admitted <- codes
    [ "module M"
    , "fn attempt() -> Result[Int, Str] { Ok(1) }"
    , "fn run() -> Result[Int, Str] {"
    , "  let value = attempt()?"
    , "  Ok(value + 1)"
    , "}"
    ]
  wrongCarrier <- codes
    [ "module M"
    , "fn attempt() -> Result[Int, Str] { Ok(1) }"
    , "fn run() -> Int { attempt()? }"
    ]
  wrongFailure <- codes
    [ "module M"
    , "fn attempt() -> Result[Int, Str] { Ok(1) }"
    , "fn run() -> Result[Int, Bool] {"
    , "  let value = attempt()?"
    , "  Ok(value)"
    , "}"
    ]
  pure $ conjoin
    [ admitted === []
    , counterexample "? needs a carrier return type" (wrongCarrier === ["E3011"])
    , counterexample "the failure types must agree" (wrongFailure === ["E3001"])
    ]

testIterationTypes :: IO Property
testIterationTypes = do
  arrayElement <- codes
    ["module M", "fn run(xs: Array[Int]) -> Int { var n = 0", "  for x in xs { n = n + x }", "  n }"]
  wrongElement <- codes
    ["module M", "fn run(xs: Array[Int]) -> Int { var n = 0", "  for x in xs { n = n + x.length() }", "  n }"]
  wrongElementOfLiteral <- codes
    ["module M", "fn run() -> Int { var n = 0", "  for x in [1, 2, 3] { n = n + x.length() }", "  n }"]
  textElement <- codes
    ["module M", "fn run(t: Str) -> Int { var n = 0", "  for c in t { n = n + c.code() }", "  n }"]
  optionElement <- codes
    ["module M", "fn run(o: Option[Int]) -> Int { var n = 0", "  for x in o { n = n + x }", "  n }"]
  notIterable <- codes
    [ "module M"
    , "type Thing = { v: Int }"
    , "fn run(t: Thing) -> Int { var n = 0"
    , "  for x in t { n = n + 1 }"
    , "  n }"
    ]
  ownSequence <- codes
    [ "module M"
    , "import Std.Iter {Sequence}"
    , "type Down = { from: Int }"
    , "impl Sequence[Int, Int] for Down {"
    , "  fn begin(self: &Self) -> Int { self.from }"
    , "  fn advance(self: &Self, state: Int) -> Option[(Int, Int)] {"
    , "    if state > 0 { Some((state - 1, state)) } else { None }"
    , "  }"
    , "}"
    , "fn run(d: Down) -> Int { var n = 0"
    , "  for x in d { n = n + x }"
    , "  n }"
    ]
  pure $ conjoin
    [ counterexample "an array yields its element type" (arrayElement === [])
    , counterexample "and a wrong use of it is now caught" (wrongElement === ["E3005"])
    , counterexample "including over a literal, whose element is settled first"
        (wrongElementOfLiteral === ["E3005"])
    , counterexample "a string yields Char" (textElement === [])
    , counterexample "a sum yields what its variants carry" (optionElement === [])
    , counterexample "a type that is not a sequence is reported at the for"
        (notIterable === ["E3030"])
    , counterexample "a type implementing Sequence is iterable"
        (ownSequence === [])
    ]
