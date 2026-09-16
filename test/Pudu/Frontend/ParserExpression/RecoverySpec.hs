{-| @Test.Frontend.ParserExpression.RecoverySpec — recovery, keywords, hostile nesting chains, and budget exhaustion -}
module Pudu.Frontend.ParserExpression.RecoverySpec
  ( recoveryProperties
  , testExhaustedBudgetIsQuiet
  , testHostileAmbiguousTails
  , testHostileChains
  , testHostileConditionals
  , testRecovery
  , testReservedKeywords
  ) where

import qualified Data.Text as Text
import Test.QuickCheck (Property, conjoin, counterexample, (===))

import Pudu.Frontend.ParserExpression.Common
  ( codes
  , diagnosticOffsets
  , helps
  , parse
  , resultKind
  )
import Pudu.Frontend.Token (TokenKind (..))

recoveryProperties :: [(String, IO Property)]
recoveryProperties =
  [ ("expression recovery emits exact diagnostics", testRecovery)
  , ("reserved keywords produce E1041 with guidance", testReservedKeywords)
  , ("hostile postfix and binary chains share the nesting budget", testHostileChains)
  , ("hostile ambiguous tails share the nesting budget", testHostileAmbiguousTails)
  , ("hostile else-if chains share the nesting budget", testHostileConditionals)
  , ("an exhausted budget reports once and stops", testExhaustedBudgetIsQuiet)
  ]

testRecovery :: IO Property
testRecovery = do
  missing <- parse "a +"
  invalid <- parse ")"
  malformedElse <- parse "if true {} else 1"
  delimited <- parse "(a +)"
  emptyHole <- parse "\"{}\""
  colonInExpr <- parse ": BigInt"
  shiftWithoutLeft <- parse "<< 100"
  pure $ conjoin
    [ codes missing === ["E1040"]
    , codes invalid === ["E1040"]
    , codes malformedElse === ["E1042"]
    , diagnosticOffsets malformedElse === [16]
    , codes delimited === ["E1040"]
    , resultKind delimited === EndOfFile
    , counterexample "colon in expression suggests binding type annotation"
        (helps colonInExpr === ["type annotations belong on bindings ('let name: Type = value')"])
    , counterexample "binary operator without left operand explains binary expectation"
        (helps shiftWithoutLeft === ["binary operators connect two expressions; provide a left-hand operand or check preceding syntax"])
    , counterexample "the parser adds nothing to an invalid string"
        (codes emptyHole === [])
    ]

testReservedKeywords :: IO Property
testReservedKeywords = do
  enumKw <- parse "enum Color { Red, Green, Blue }"
  structKw <- parse "struct Point { x: Int, y: Int }"
  taskKw <- parse "task foo() -> Int { 42 }"
  spawnKw <- parse "spawn bar()"
  moduleKw <- parse "module M"
  mutKw <- parse "mut x = 5"
  pure $ conjoin
    [ counterexample "enum produces E1041" (codes enumKw === ["E1041"])
    , counterexample "enum help points to type" (helps enumKw === ["enum is reserved; use type for sum and record declarations"])
    , counterexample "struct produces E1041" (codes structKw === ["E1041"])
    , counterexample "struct help points to type" (helps structKw === ["struct is reserved; use type for record declarations"])
    , counterexample "task produces E1041" (codes taskKw === ["E1041"])
    , counterexample "task help points to async fn and scope" (helps taskKw === ["task is reserved; use async fn and scope for structured concurrency"])
    , counterexample "spawn produces E1041" (codes spawnKw === ["E1041"])
    , counterexample "spawn help points to async fn and scope" (helps spawnKw === ["spawn is reserved; use async fn and scope for structured concurrency"])
    , counterexample "module produces E1041" (codes moduleKw === ["E1041"])
    , counterexample "module help explains file-only" (helps moduleKw === ["module declarations are only valid at the top of a file"])
    , counterexample "mut produces E1041" (codes mutKw === ["E1041"])
    , counterexample "mut help points to var" (helps mutKw === ["use var for mutable bindings; mut modifies references and fields"])
    , counterexample "enum recovers without cascade" (resultKind enumKw === EndOfFile)
    , counterexample "struct recovers without cascade" (resultKind structKw === EndOfFile)
    , counterexample "task recovers without cascade" (resultKind taskKw === EndOfFile)
    , counterexample "spawn recovers without cascade" (resultKind spawnKw === EndOfFile)
    , counterexample "module recovers without cascade" (resultKind moduleKw === EndOfFile)
    , counterexample "mut recovers without cascade" (resultKind mutKw === EndOfFile)
    ]

testHostileChains :: IO Property
testHostileChains = do
  members <- parse ("root" <> Text.concat (replicate 520 ".x"))
  binaries <- parse ("a" <> Text.concat (replicate 520 " + a"))
  arguments <- parse ("f(" <> Text.intercalate "," (replicate 520 "a") <> ")")
  setMembers <- parse ("#{" <> Text.intercalate "," (replicate 520 "a") <> "}")
  pure $ conjoin
    [ codes members === ["E1099"]
    , codes binaries === ["E1099"]
    , codes arguments === ["E1099"]
    , codes setMembers === ["E1099"]
    , diagnosticOffsets arguments === [1022]
    ]

testHostileAmbiguousTails :: IO Property
testHostileAmbiguousTails = do
  let tailLines = Text.concat (replicate 520 "\n- c")
  delimited <- parse ("(a\n+ b" <> tailLines <> ")")
  pure $ conjoin
    [ counterexample "the ambiguity is owned once before budget exhaustion"
        (codes delimited === ["E1055", "E1099"])
    , counterexample "budget exhaustion suppresses missing-delimiter cascades"
        (length (codes delimited) === 2)
    ]

testHostileConditionals :: IO Property
testHostileConditionals = do
  let input = "if true {}" <> Text.concat (replicate 519 " else if true {}")
      patternInput =
        "if let Some(value) = Some(1) {}"
          <> Text.concat (replicate 519 " else if let Some(value) = Some(1) {}")
  result <- parse input
  patternResult <- parse patternInput
  pure $ conjoin
    [ codes result === ["E1099"]
    , diagnosticOffsets result === [8179]
    , counterexample "if let chains use the same shared budget"
        (codes patternResult === ["E1099"])
    ]

testExhaustedBudgetIsQuiet :: IO Property
testExhaustedBudgetIsQuiet = do
  balanced <- parse (Text.replicate 5000 "(" <> "1" <> Text.replicate 5000 ")")
  unclosed <- parse (Text.replicate 5000 "(" <> "1")
  brackets <- parse (Text.replicate 5000 "[" <> Text.replicate 5000 "]")
  pure $ conjoin
    [ counterexample "a balanced flood reports once" (codes balanced === ["E1099"])
    , counterexample "an unclosed flood reports once" (codes unclosed === ["E1099"])
    , counterexample "and so does a bracket flood" (codes brackets === ["E1099"])
    ]
