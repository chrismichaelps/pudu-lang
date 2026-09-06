{-| @Test.Type.Check.PatternSpec — match exhaustiveness, reachability, and borrow pattern matching -}
module Pudu.Type.Check.PatternSpec
  ( patternProperties
  , testExhaustiveness
  , testMatchThroughBorrow
  ) where

import Pudu.Type.Check.Common
  ( codes
  , codesOfExpression
  , typeOf
  )
import Pudu.Type.Check.DataSpec (colorProgram)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

patternProperties :: [(String, IO Property)]
patternProperties =
  [ ("a match reads through a borrow", testMatchThroughBorrow)
  , ("matches are checked for coverage and reachability", testExhaustiveness)
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
