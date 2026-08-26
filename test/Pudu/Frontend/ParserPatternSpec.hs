module Pudu.Frontend.ParserPatternSpec (parserPatternProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText, diagnosticSpan)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Pattern (parsePattern)
import Pudu.Frontend.Parser.State (peekKind, runParser)
import Pudu.Frontend.Syntax
  ( FieldPattern (..)
  , Literal (..)
  , Located (..)
  , Pattern (..)
  , moduleNameText
  )
import Pudu.Frontend.Token (TokenKind (..))
import Pudu.Source (SourceName (SourceName), newSource, spanEnd, spanStart, unOffset)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

type Parsed = (Located Pattern, TokenKind, [Diagnostic])

parserPatternProperties :: [(String, IO Property)]
parserPatternProperties =
  [ ("wildcards bindings and literals classify exactly", testAtoms)
  , ("constructors carry positional and record payloads", testConstructors)
  , ("tuples group and nest", testTuples)
  , ("record patterns bind fields and admit a rest", testRecords)
  , ("alternation and ranges parse", testAlternationRanges)
  , ("invalid pattern starts emit E1050 once", testRecovery)
  , ("hostile pattern nesting shares the budget", testHostileNesting)
  ]

testAtoms :: IO Property
testAtoms = do
  wildcard <- parse "_"
  binding <- parse "value"
  underscored <- parse "_unused"
  integer <- parse "42"
  negative <- parse "-7"
  text <- parse "\"ok\""
  boolean <- parse "true"
  nullValue <- parse "null"
  pure $ conjoin
    [ shape wildcard === "_"
    , shape binding === "value"
    , shape underscored === "_unused"
    , shape integer === "42"
    , counterexample "negative literals keep their sign" (shape negative === "-7")
    , shape text === "ok"
    , shape boolean === "true"
    , shape nullValue === "null"
    , codes negative === []
    , counterexample "spans cover the sign" (spanOffsets negative === (0, 2))
    ]

testConstructors :: IO Property
testConstructors = do
  bare <- parse "None"
  positional <- parse "Ok(value)"
  qualified <- parse "Core.Result.Err(error)"
  record <- parse "User{id, name: label}"
  nested <- parse "Ok(Some(inner))"
  pure $ conjoin
    [ shape bare === "None"
    , shape positional === "Ok(value)"
    , shape qualified === "Core.Result.Err(error)"
    , shape record === "User{id,name:label}"
    , shape nested === "Ok(Some(inner))"
    , codes record === []
    ]

testTuples :: IO Property
testTuples = do
  pair <- parse "(first, second)"
  grouped <- parse "(only)"
  trailing <- parse "(a, b,)"
  nested <- parse "((a, b), c)"
  pure $ conjoin
    [ shape pair === "(first,second)"
    , counterexample "a single member without a comma groups" (shape grouped === "only")
    , shape trailing === "(a,b)"
    , shape nested === "((a,b),c)"
    ]

testRecords :: IO Property
testRecords = do
  shorthand <- parse "{id, name}"
  renamed <- parse "{id: key}"
  rest <- parse "{id, ..}"
  pure $ conjoin
    [ shape shorthand === "{id,name}"
    , shape renamed === "{id:key}"
    , counterexample "rest is recorded" (shape rest === "{id,..}")
    , codes rest === []
    ]

testAlternationRanges :: IO Property
testAlternationRanges = do
  alternation <- parse "Ok(v) | Err(v)"
  literals <- parse "1 | 2 | 3"
  exclusive <- parse "1..10"
  inclusive <- parse "'a'..='z'"
  negatives <- parse "-5..=5"
  pure $ conjoin
    [ shape alternation === "Ok(v)|Err(v)"
    , shape literals === "1|2|3"
    , shape exclusive === "1..10"
    , shape inclusive === "a..=z"
    , shape negatives === "-5..=5"
    , codes negatives === []
    ]

testRecovery :: IO Property
testRecovery = do
  operator <- parse "+"
  unclosed <- parse "(a"
  missingBound <- parse "1..)"
  pure $ conjoin
    [ counterexample "invalid start" (codes operator === ["E1050"])
    , shape operator === "invalid"
    , counterexample "unclosed tuple" (codes unclosed === ["E1000"])
    , counterexample "missing range endpoint" (codes missingBound === ["E1050"])
    , diagnosticOffsets operator === [0]
    ]

testHostileNesting :: IO Property
testHostileNesting = do
  let input = Text.concat (replicate 520 "(") <> "a" <> Text.concat (replicate 520 ")")
  result <- parse input
  pure (counterexample "one budget diagnostic" (codes result === ["E1099"]))

parse :: Text -> IO Parsed
parse input = do
  source <- newSource (SourceName "pattern.pudu") input
  let LexResult{lexTokens} = lexSource source
      action = (,) <$> parsePattern <*> peekKind
      ((parsed, remaining), diagnostics) = runParser source action lexTokens
  pure (parsed, remaining, diagnostics)

codes :: Parsed -> [Text]
codes (_, _, diagnostics) = map (diagnosticCodeText . diagnosticCode) diagnostics

diagnosticOffsets :: Parsed -> [Int]
diagnosticOffsets (_, _, diagnostics) = map (unOffset . spanStart . diagnosticSpan) diagnostics

spanOffsets :: Parsed -> (Int, Int)
spanOffsets (Located spanValue _, _, _) = (unOffset (spanStart spanValue), unOffset (spanEnd spanValue))

shape :: Parsed -> Text
shape (pattern', _, _) = patternShape pattern'

patternShape :: Located Pattern -> Text
patternShape (Located _ value) = case value of
  WildcardPattern -> "_"
  BindingPattern name -> locatedValue name
  LiteralPattern literalValue -> literalShape literalValue
  RangePattern lower inclusive upper ->
    literalShape lower <> (if inclusive then "..=" else "..") <> literalShape upper
  TuplePattern members -> "(" <> Text.intercalate "," (map patternShape members) <> ")"
  ConstructorPattern path arguments ->
    moduleNameText path
      <> if null arguments then Text.empty
         else "(" <> Text.intercalate "," (map patternShape arguments) <> ")"
  RecordPattern path fields rest ->
    maybe Text.empty moduleNameText path
      <> "{" <> Text.intercalate "," (map fieldShape fields)
      <> (if rest then ",.." else Text.empty) <> "}"
  AlternativePattern alternatives -> Text.intercalate "|" (map patternShape alternatives)
  InvalidPattern -> "invalid"

fieldShape :: Located FieldPattern -> Text
fieldShape (Located _ field) =
  locatedValue (fieldPatternName field)
    <> maybe Text.empty (\value -> ":" <> patternShape value) (fieldPatternValue field)

literalShape :: Literal -> Text
literalShape value = case value of
  IntegerValue text -> text
  FloatValue text -> text
  DecimalValue text -> text
  StringValue text -> text
  CharValue character -> Text.singleton character
  BoolValue flag -> if flag then "true" else "false"
  NullValue -> "null"
