{-| @Test.Frontend.ParserExpression.RecoverySpec — recovery, keywords, hostile nesting chains, and budget exhaustion -}
module Pudu.Frontend.ParserExpression.RecoverySpec
  ( recoveryProperties
  , testExhaustedBudgetIsQuiet
  , testFlatLists
  , testHostileAmbiguousTails
  , testHostileChains
  , testHostileConditionals
  , testRecovery
  , testReservedKeywords
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Test.QuickCheck (Property, conjoin, counterexample, (.&&.), (===))

import Pudu.Frontend.ParserExpression.Common
  ( codes
  , diagnosticOffsets
  , helps
  , parse
  , resultKind
  )
import Pudu.Frontend.Syntax (Expression (..), Literal (..), Located (..))
import Pudu.Frontend.Token (TokenKind (..))
import Pudu.Source (spanEnd, spanStart, unOffset)

recoveryProperties :: [(String, IO Property)]
recoveryProperties =
  [ ("expression recovery emits exact diagnostics", testRecovery)
  , ("reserved keywords produce E1041 with guidance", testReservedKeywords)
  , ("hostile postfix and binary chains share the nesting budget", testHostileChains)
  , ("hostile ambiguous tails share the nesting budget", testHostileAmbiguousTails)
  , ("hostile else-if chains share the nesting budget", testHostileConditionals)
  , ("an exhausted budget reports once and stops", testExhaustedBudgetIsQuiet)
  , ("flat list width does not consume nesting depth", testFlatLists)
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
    , counterexample "a wide call is not deep" (codes arguments === [])
    , counterexample "a wide Set is not deep" (codes setMembers === [])
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

{-| Width is not depth: 2,048 siblings parse completely, in order, with each
    item's span at its own source text; nesting after many siblings still
    parses; deep nesting still refuses once; malformed lists still recover. -}
testFlatLists :: IO Property
testFlatLists = do
  let width = 2048 :: Int
      items = map (Text.pack . show) [1 .. width]
      joined = Text.intercalate ", " items
  wideCases <- mapM (\(kind, opening, closing, trailing) -> do
    let input = opening <> joined <> (if trailing then "," else "") <> closing
        offsets = take width (scanl (\at item -> at + Text.length item + 2) (Text.length opening) items)
    result <- parse input
    pure $ counterexample (Text.unpack kind <> " trailing=" <> show trailing) $ conjoin
      [ codes result === []
      , listKind result === Just kind
      , itemTexts result === Just items
      , itemStarts result === Just offsets
      , itemWidths result === Just (map Text.length items)
      , sourceBounds result === (0, Text.length input)
      ]) [(kind, opening, closing, trailing)
         | (kind, opening, closing) <- [("array", "[", "]"), ("Set", "#{", "}"), ("call", "f(", ")")]
         , trailing <- [False, True]]
  nestedAfter <- parse ("[" <> joined <> ", [[[1, 2], #{3}], g(4, [5])]]")
  deepArray <- parse (Text.replicate 600 "[" <> Text.replicate 600 "]")
  deepSet <- parse (Text.replicate 600 "#{" <> "1" <> Text.replicate 600 "}")
  deepCall <- parse (Text.replicate 600 "f(" <> "1" <> Text.replicate 600 ")")
  wideThenDeep <- parse ("[" <> joined <> ", " <> Text.replicate 600 "[" <> Text.replicate 600 "]" <> "]")
  missing <- parse "[1, , 2]"
  unclosed <- parse ("[" <> joined)
  missingArgument <- parse "f(1, , 2)"
  pure $ conjoin
    (wideCases ++
    [ counterexample "nesting after many siblings parses" (codes nestedAfter === [] .&&. resultKind nestedAfter === EndOfFile)
    , counterexample "a deep array still refuses once" (codes deepArray === ["E1099"])
    , counterexample "a deep Set still refuses once" (codes deepSet === ["E1099"])
    , counterexample "a deep call still refuses once" (codes deepCall === ["E1099"])
    , counterexample "depth after width refuses once" (codes wideThenDeep === ["E1099"])
    , counterexample "a missing element recovers" (codes missing === ["E1001", "E1040"])
    , counterexample "an unclosed wide array reports its end" (codes unclosed === ["E1000"])
    , counterexample "a missing argument recovers" (codes missingArgument === ["E1040"])
    ])

listItems :: (Located Expression, TokenKind, a) -> Maybe [Located Expression]
listItems (Located _ expression, EndOfFile, _) = case expression of
  ArrayExpression values -> Just values
  SetExpression values -> Just values
  CallExpression _ values -> Just values
  _ -> Nothing
listItems _ = Nothing

itemTexts :: (Located Expression, TokenKind, a) -> Maybe [Text]
itemTexts result = traverse integerText =<< listItems result
  where
    integerText (Located _ (LiteralExpression (IntegerValue value))) = Just value
    integerText _ = Nothing

itemStarts :: (Located Expression, TokenKind, a) -> Maybe [Int]
itemStarts result = map (unOffset . spanStart . locatedSpan) <$> listItems result

itemWidths :: (Located Expression, TokenKind, a) -> Maybe [Int]
itemWidths result = map (width . locatedSpan) <$> listItems result
  where
    width spanValue = unOffset (spanEnd spanValue) - unOffset (spanStart spanValue)

listKind :: (Located Expression, TokenKind, a) -> Maybe Text
listKind (Located _ expression, EndOfFile, _) = case expression of
  ArrayExpression _ -> Just "array"
  SetExpression _ -> Just "Set"
  CallExpression _ _ -> Just "call"
  _ -> Nothing
listKind _ = Nothing

sourceBounds :: (Located Expression, TokenKind, a) -> (Int, Int)
sourceBounds (Located spanValue _, _, _) =
  (unOffset (spanStart spanValue), unOffset (spanEnd spanValue))
