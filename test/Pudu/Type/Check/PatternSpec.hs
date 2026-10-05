{-| @Test.Type.Check.PatternSpec — match exhaustiveness, reachability, and borrow pattern matching -}
module Pudu.Type.Check.PatternSpec
  ( patternProperties
  , testExhaustiveness
  , testTupleCoverage
  , testNestedConstructorNamespaces
  , testMatchThroughBorrow
  ) where

import qualified Pudu.Compiler.Program.Common as Program
import Pudu.Type.Check.Common
  ( codes
  , codesOfExpression
  , typeOf
  , compile
  , diagnosticContract
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Type.Check.DataSpec (colorProgram)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

patternProperties :: [(String, IO Property)]
patternProperties =
  [ ("a match reads through a borrow", testMatchThroughBorrow)
  , ("matches are checked for coverage and reachability", testExhaustiveness)
  , ("tuple coverage retains correlated Option combinations", testTupleCoverage)
  , ("nested coverage follows canonical constructor owners", testNestedConstructorNamespaces)
  ]

testExhaustiveness :: IO Property
testExhaustiveness = do
  complete <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red => 1"
    , "    case Green => 2"
    , "    case Blue => 3"
    , "  }"
    , "}"
    ])
  missing <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red => 1"
    , "    case Green => 2"
    , "  }"
    , "}"
    ])
  wildcard <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red => 1"
    , "    case _ => 0"
    , "  }"
    , "}"
    ])
  guarded <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red => 1"
    , "    case Green => 2"
    , "    case other if true => 3"
    , "  }"
    , "}"
    ])
  option <- codes ["module M", "fn run(value: Option[Int]) -> Int { match value { case Some(v) => v } }"]
  openDomain <- codes ["module M", "fn run(value: Int) -> Int { match value { case 1 => 1 } }"]
  unreachable <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case _ => 0"
    , "    case Red => 1"
    , "  }"
    , "}"
    ])
  payloadTested <- codes ["module M", "fn run(value: Option[Int]) -> Int { match value { case Some(1) => 1 case None => 0 } }"]
  repeatedName <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red => 1"
    , "    case Red => 2"
    , "    case Green => 3"
    , "    case Blue => 4"
    , "  }"
    , "}"
    ])
  repeatedLiteral <- codes
    [ "module M"
    , "fn run(n: Int) -> Int { match n { case 1 => 1 case 1 => 2 case _ => 0 } }"
    ]
  repeatedAlternative <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red | Green => 1"
    , "    case Red => 2"
    , "    case Blue => 3"
    , "  }"
    , "}"
    ])
  widerAlternative <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red | Green => 1"
    , "    case Green | Blue => 2"
    , "  }"
    , "}"
    ])
  distinctPayloads <- codes
    [ "module M"
    , "fn run(value: Option[Int]) -> Int {"
    , "  match value { case Some(1) => 1 case Some(2) => 2 case Some(n) => n case None => 0 }"
    , "}"
    ]
  capturedWrite <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  var seen = 0"
    , "  let bump = fn() -> Int {"
    , "    seen = 9"
    , "    1"
    , "  }"
    , "  let _ran = bump()"
    , "  seen"
    , "}"
    ]
  ownWrite <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  let counted = fn() -> Int {"
    , "    var inner = 0"
    , "    inner = 5"
    , "    inner"
    , "  }"
    , "  counted()"
    , "}"
    ]
  outerWrite <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  var seen = 0"
    , "  seen = 9"
    , "  seen"
    , "}"
    ]
  derefWrite <- codes
    [ "module M"
    , "fn bump(score: &mut Int) -> () {"
    , "  *score = *score + 1"
    , "}"
    ]
  fieldWrite <- codes
    [ "module M"
    , "type Tally = { mut count: Int }"
    , "fn run() -> Int {"
    , "  var tally = Tally{count: 1}"
    , "  tally.count = 2"
    , "  tally.count"
    , "}"
    ]
  elementWrite <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  var items = [1, 2]"
    , "  items[0] = 5"
    , "  items[0]"
    , "}"
    ]
  nestedBooleans <- codes
    [ "module M"
    , "fn run(value: Result[Bool, Int]) -> Int {"
    , "  match value { case Err(_) => 0 case Ok(true) => 1 case Ok(false) => 2 }"
    , "}"
    ]
  nestedVariants <- codes
    [ "module M"
    , "fn run(value: Result[Option[Int], Int]) -> Int {"
    , "  match value { case Err(_) => 0 case Ok(None) => 1 case Ok(Some(_)) => 2 }"
    , "}"
    ]
  nestedHalfBoolean <- codes
    [ "module M"
    , "fn run(value: Result[Bool, Int]) -> Int {"
    , "  match value { case Err(_) => 0 case Ok(true) => 1 }"
    , "}"
    ]
  nestedHalfVariant <- codes
    [ "module M"
    , "fn run(value: Result[Option[Int], Int]) -> Int {"
    , "  match value { case Err(_) => 0 case Ok(None) => 1 }"
    , "}"
    ]
  nestedLiteral <- codes
    [ "module M"
    , "fn run(value: Result[Int, Int]) -> Int {"
    , "  match value { case Err(_) => 0 case Ok(1) => 1 }"
    , "}"
    ]
  guardTakesNothing <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red if false => 0"
    , "    case Red => 1"
    , "    case Green => 2"
    , "    case Blue => 3"
    , "  }"
    , "}"
    ])
  pure $ conjoin
    [ counterexample "every constructor covered" (complete === [])
    , counterexample "a missing constructor is reported" (missing === ["E5001"])
    , counterexample "a wildcard covers the rest" (wildcard === [])
    , counterexample "a guarded arm does not cover" (guarded === ["E5001"])
    , counterexample "Option must cover None" (option === ["E5001"])
    , counterexample "an open domain needs a wildcard" (openDomain === ["E5001"])
    , counterexample "two booleans under one constructor cover it"
        (nestedBooleans === [])
    , counterexample "two variants under one constructor cover it"
        (nestedVariants === [])
    , counterexample "one of two booleans does not" (nestedHalfBoolean === ["E5001"])
    , counterexample "one of two variants does not" (nestedHalfVariant === ["E5001"])
    , counterexample "a literal payload covers nothing" (nestedLiteral === ["E5001"])
    , counterexample "a write to a captured name is refused" (capturedWrite === ["E3076"])
    , counterexample "a closure writes its own bindings" (ownWrite === [])
    , counterexample "a write outside any closure is untouched" (outerWrite === [])
    , counterexample "a write through an exclusive reference is accepted" (derefWrite === [])
    , counterexample "a write to a mut field of a var is accepted" (fieldWrite === [])
    , counterexample "a write to an element of a var array is accepted" (elementWrite === [])
    , counterexample "an arm after a wildcard is unreachable" (unreachable === ["W5001"])
    , counterexample "a tested payload does not cover its constructor"
        (payloadTested === ["E5001"])
    , counterexample "a repeated constructor is unreachable" (repeatedName === ["W5001"])
    , counterexample "a repeated literal is unreachable" (repeatedLiteral === ["W5001"])
    , counterexample "a name an earlier alternative took is unreachable"
        (repeatedAlternative === ["W5001"])
    , counterexample "an alternative naming something new is reachable"
        (widerAlternative === [])
    , counterexample "distinct payload tests do not subsume each other"
        (distinctPayloads === [])
    , counterexample "a guarded arm leaves its pattern for a later one"
        (guardTakesNothing === [])
    ]

testMatchThroughBorrow :: IO Property
testMatchThroughBorrow = do
  borrowed <- codes
    [ "module M"
    , "fn ask(value: &Option[Int]) -> Bool {"
    , "  match value {"
    , "    case Some(_) => true"
    , "    case None => false"
    , "  }"
    , "}"
    ]
  owned <- codes
    [ "module M"
    , "fn ask(value: Option[Int]) -> Bool {"
    , "  match value {"
    , "    case Some(_) => true"
    , "    case None => false"
    , "  }"
    , "}"
    ]
  stillExhaustive <- codes
    [ "module M"
    , "fn ask(value: &Option[Int]) -> Bool {"
    , "  match value {"
    , "    case Some(_) => true"
    , "  }"
    , "}"
    ]
  charCode <- typeOf "'a'.code()"
  unknownChar <- codesOfExpression "'a'.isDigit()"
  pure $ conjoin
    [ counterexample "a borrowed subject matches" (borrowed === [])
    , counterexample "an owned subject still matches" (owned === [])
    , counterexample "exhaustiveness is still checked through the borrow"
        (stillExhaustive === ["E5001"])
    , counterexample "a character answers for its code" (charCode === "Int")
    , counterexample "a character has no other method" (unknownChar === ["E3005"])
    ]

{-| Complete products must check, but independent coverage of their columns
    must never stand in for coverage of every combination. -}
testTupleCoverage :: IO Property
testTupleCoverage = do
  complete <- codes (program "(Option[Int], Option[Int])"
    ["(Some(_), Some(_))", "(Some(_), None)", "(None, Some(_))", "(None, None)"])
  grouped <- codes (program "(Option[Int], Option[Int])"
    ["(Some(_), _)", "(None, Some(_))", "(None, None)"])
  diagonal <- codes (program "(Option[Int], Option[Int])"
    ["(Some(_), Some(_))", "(None, None)"])
  guarded <- codes (program "(Option[Int], Option[Int])"
    ["(Some(_), _)", "(None, Some(_))", "(None, None) if true"])
  payload <- codes (program "(Option[Int], Option[Int])"
    ["(Some(1), _)", "(None, _)"])
  booleans <- codes (program "(Bool, Bool)"
    ["(true, true)", "(true, false)", "(false, true)", "(false, false)"])
  diagonalBool <- codes (program "(Bool, Bool)" ["(true, true)", "(false, false)"])
  nested <- codes (program "((Option[Int], Bool), Option[Int])"
    ["((Some(_), _), _)", "((None, true), _)", "((None, false), _)"])
  alternatives <- codes (program "(Bool, Bool)" ["(true | false, true)", "(_, false)"])
  let source = Text.unlines (program "(Option[Int], Option[Int])"
        ["(Some(_), _)", "(None, Some(_))"])
  missing <- compile source
  pure $ conjoin
    [ counterexample "all four combinations" (complete === [])
    , counterexample "grouped wildcard covers all combinations" (grouped === [])
    , counterexample "diagonal leaves two combinations" (diagonal === ["E5001"])
    , counterexample "guarded last combination remains missing" (guarded === ["E5001"])
    , counterexample "open payload test leaves values" (payload === ["E5001"])
    , counterexample "boolean product" (booleans === [])
    , counterexample "boolean diagonal remains incomplete" (diagonalBool === ["E5001"])
    , counterexample "nested tuple product" (nested === [])
    , counterexample "alternatives specialize without losing their row" (alternatives === [])
    , diagnosticContract source "match value" "E5001"
        "match on (Option[Int], Option[Int]) does not cover every value"
        (Just "add a wildcard case for the values the arms do not name") missing
    ]
 where
  program :: Text -> [Text] -> [Text]
  program subject patterns =
    ["module M", "fn run(value: " <> subject <> ") -> Int {", "  match value {"]
      <> ["    case " <> held <> " => 0" | held <- patterns]
      <> ["  }", "}"]

{-| An unrelated dependency's constructors must neither remove nor supply
    coverage for the canonical type actually carried by an Option. -}
testNestedConstructorNamespaces :: IO Property
testNestedConstructorNamespaces = do
  complete <- Program.codes "test-fixtures/exhaustnamespace/UsesJsonCoverage.pudu"
  reverseOrder <- Program.codes "test-fixtures/exhaustnamespace/UsesJsonCoverageReversed.pudu"
  directValue <- Program.runEntry "test-fixtures/exhaustnamespace/UsesJsonCoverage.pudu"
  indirectValue <- Program.runEntry "test-fixtures/exhaustnamespace/UsesJsonCoverageReversed.pudu"
  missing <- Program.codes "test-fixtures/exhaustnamespace/RejectsJsonCoverage.pudu"
  missingMessages <- Program.messages "test-fixtures/exhaustnamespace/RejectsJsonCoverage.pudu"
  genericProduct <- codes
    [ "module M"
    , "type Pair[T] = Empty | Both(T, T)"
    , "fn run(value: Pair[Bool]) -> Int {"
    , "  match value {"
    , "    case Empty => 0"
    , "    case Both(true, _) => 1"
    , "    case Both(false, true) => 2"
    , "    case Both(false, false) => 3"
    , "  }"
    , "}"
    ]
  genericDiagonal <- codes
    [ "module M"
    , "type Pair[T] = Empty | Both(T, T)"
    , "fn run(value: Pair[Bool]) -> Int {"
    , "  match value {"
    , "    case Empty => 0"
    , "    case Both(true, true) => 1"
    , "    case Both(false, false) => 2"
    , "  }"
    , "}"
    ]
  nestedTuple <- codes
    [ "module M"
    , "fn run(value: Option[(Bool, Bool)]) -> Int {"
    , "  match value {"
    , "    case None => 0"
    , "    case Some((true, _)) => 1"
    , "    case Some((false, true)) => 2"
    , "    case Some((false, false)) => 3"
    , "  }"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "Json cannot remove nested Option coverage" (complete === [])
    , counterexample "dependency order cannot select another constructor owner" (reverseOrder === [])
    , counterexample "every local Atom/Value branch and Json executes" (directValue === Just "\"10:true\"")
    , counterexample "indirect Json loading preserves runtime output" (indirectValue === directValue)
    , counterexample "Json cannot supply a missing local Text branch" (missing === ["E5001"])
    , counterexample "missing nested branch retains constructor diagnostic"
        (missingMessages === ["match on Option does not cover Some"])
    , counterexample "generic positional product is instantiated before coverage" (genericProduct === [])
    , counterexample "generic product correlation remains exact" (genericDiagonal === ["E5001"])
    , counterexample "a tuple payload is checked at its actual instantiated type" (nestedTuple === [])
    ]
