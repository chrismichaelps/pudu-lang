module Pudu.Frontend.ParserExpressionSpec (parserExpressionProperties) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText, diagnosticSpan)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Expression (parseExpression)
import Pudu.Frontend.Parser.State (Parser, expectSymbol, peekKind, runParser)
import Pudu.Frontend.Syntax
  ( Block (..)
  , Expression (..)
  , FieldPattern (..)
  , Literal (..)
  , Located (..)
  , MatchArm (..)
  , Pattern (..)
  , moduleNameText
  )
import Pudu.Frontend.Token (Token (tokenSpan), TokenKind (..))
import Pudu.Source (SourceName (SourceName), mergeSpans, newSource, spanStart, unOffset)
import Test.QuickCheck (Property, conjoin, (===))

parserExpressionProperties :: [(String, IO Property)]
parserExpressionProperties =
  [ ("binary precedence and associativity are explicit", testPrecedence)
  , ("closed binary vocabulary parses exhaustively", testBinaryVocabulary)
  , ("literal vocabulary maps into expression nodes", testLiterals)
  , ("postfix calls and members bind before binary operators", testPostfix)
  , ("unary borrow and conditional blocks preserve structure", testUnaryIf)
  , ("expression recovery emits exact diagnostics", testRecovery)
  , ("index failure-propagation and await postfix forms parse", testPostfixForms)
  , ("match while loop and for parse as expressions", testControlExpressions)
  , ("hostile postfix and binary chains share the nesting budget", testHostileChains)
  , ("hostile else-if chains share the nesting budget", testHostileConditionals)
  ]

testPrecedence :: IO Property
testPrecedence = do
  assignment <- parse "a = b = c"
  subtraction <- parse "a - b - c"
  mixed <- parse "a + b * c"
  pure $ conjoin [validShape assignment === "(a=(b=c))",
    validShape subtraction === "((a-b)-c)", validShape mixed === "(a+(b*c))"]

testBinaryVocabulary :: IO Property
testBinaryVocabulary = do
  let operators = ["=", "||", "&&", "==", "!=", "<", "<=", ">", ">=", "..", "..=",
        "+", "-", "&+", "&-", "+|", "-|", "*", "/", "%", "&*", "*|"]
  results <- traverse (\operator -> parse ("a " <> operator <> " b")) operators
  pure (map validShape results === map (\operator -> "(a" <> operator <> "b)") operators)

testLiterals :: IO Property
testLiterals = do
  results <- traverse parse ["1", "1.5", "\"hi\"", "'x'", "true", "false", "null"]
  pure (map validShape results === ["1", "1.5", "hi", "x", "true", "false", "null"])

testPostfix :: IO Property
testPostfix = do
  result <- parse "service.fetch(1, 2,).name + 3"
  pure (validShape result === "(service.fetch(1,2).name+3)")

testUnaryIf :: IO Property
testUnaryIf = do
  unary <- parse "&mut -value"
  conditional <- parse "if true {} else if false {} else {}"
  pure $ conjoin [validShape unary === "(&mut(-value))", validShape conditional === "if"]

testRecovery :: IO Property
testRecovery = do
  missing <- parse "a +"
  invalid <- parse ")"
  malformedElse <- parse "if true {} else 1"
  delimited <- parse "(a +)"
  pure $ conjoin [codes missing === ["E1040"], codes invalid === ["E1040"],
    codes malformedElse === ["E1042"], diagnosticOffsets malformedElse === [16],
    codes delimited === ["E1040"], resultKind delimited === EndOfFile]

testPostfixForms :: IO Property
testPostfixForms = do
  index <- parse "a[0]"
  propagation <- parse "read()?"
  awaiting <- parse "fetch().await"
  chained <- parse "rows[i].value?.await"
  pure $ conjoin
    [ validShape index === "a[0]"
    , validShape propagation === "read()?"
    , validShape awaiting === "fetch().await"
    , validShape chained === "rows[i].value?.await"
    ]

testControlExpressions :: IO Property
testControlExpressions = do
  matched <- parse "match value {\n  case Ok(v) if v > 0 => v\n  case _ => 0\n}"
  loopValue <- parse "loop {}"
  whileValue <- parse "while ready {}"
  forValue <- parse "for item in items {}"
  pure $ conjoin
    [ validShape matched === "match(value){Ok(v) if (v>0)=>v;_=>0}"
    , validShape loopValue === "loop"
    , validShape whileValue === "while(ready)"
    , validShape forValue === "for item in items"
    ]

testHostileChains :: IO Property
testHostileChains = do
  members <- parse ("root" <> Text.concat (replicate 520 ".x"))
  binaries <- parse ("a" <> Text.concat (replicate 520 " + a"))
  arguments <- parse ("f(" <> Text.intercalate "," (replicate 520 "a") <> ")")
  pure $ conjoin [codes members === ["E1099"], codes binaries === ["E1099"],
    codes arguments === ["E1099"], diagnosticOffsets arguments === [1022]]

testHostileConditionals :: IO Property
testHostileConditionals = do
  let input = "if true {}" <> Text.concat (replicate 519 " else if true {}")
  result <- parse input
  pure $ conjoin [codes result === ["E1099"], diagnosticOffsets result === [8179]]

parse :: Text -> IO (Located Expression, TokenKind, [Diagnostic])
parse input = do
  source <- newSource (SourceName "expression.pudu") input
  let LexResult{lexTokens} = lexSource source
      action = (,) <$> parseExpression emptyBlock <*> peekKind
      ((expression, remainingKind), diagnostics) = runParser source action lexTokens
  pure (expression, remainingKind, diagnostics)

emptyBlock :: Parser (Located Block)
emptyBlock = do
  opening <- expectSymbol "{" "to start the block"
  closing <- expectSymbol "}" "to close the block"
  let spanValue = maybe (tokenSpan opening) id (mergeSpans (tokenSpan opening) (tokenSpan closing))
  pure (Located spanValue (Block [] Nothing))

validShape :: (Located Expression, TokenKind, [Diagnostic]) -> Text
validShape (expression, remainingKind, diagnostics)
  | remainingKind == EndOfFile && null diagnostics = shape expression
  | otherwise = "invalid:" <> Text.pack (show (remainingKind, map diagnosticCode diagnostics))

codes :: (Located Expression, TokenKind, [Diagnostic]) -> [Text]
codes (_, _, diagnostics) = map (diagnosticCodeText . diagnosticCode) diagnostics

diagnosticOffsets :: (Located Expression, TokenKind, [Diagnostic]) -> [Int]
diagnosticOffsets (_, _, diagnostics) = map (unOffset . spanStart . diagnosticSpan) diagnostics

resultKind :: (Located Expression, TokenKind, [Diagnostic]) -> TokenKind
resultKind (_, kind, _) = kind

shape :: Located Expression -> Text
shape (Located _ expression) = case expression of
  LiteralExpression literalValue -> literalShape literalValue
  NameExpression names -> Text.intercalate "." (NonEmpty.toList names)
  UnaryExpression operator operand -> "(" <> operator <> shape operand <> ")"
  BinaryExpression left operator right -> "(" <> shape left <> operator <> shape right <> ")"
  CallExpression callee arguments -> shape callee <> "(" <> Text.intercalate "," (map shape arguments) <> ")"
  MemberExpression target member -> shape target <> "." <> locatedValue member
  IndexExpression target index -> shape target <> "[" <> shape index <> "]"
  TryExpression target -> shape target <> "?"
  AwaitExpression target -> shape target <> ".await"
  BlockExpression _ -> "block"
  IfExpression{} -> "if"
  MatchExpression scrutinee arms ->
    "match(" <> shape scrutinee <> "){"
      <> Text.intercalate ";" (map armShape arms) <> "}"
  WhileExpression condition _ -> "while(" <> shape condition <> ")"
  LoopExpression _ -> "loop"
  ForExpression binder iterated _ ->
    "for " <> patternShape binder <> " in " <> shape iterated
  InvalidExpression -> "invalid"

armShape :: Located MatchArm -> Text
armShape (Located _ arm) =
  patternShape (armPattern arm)
    <> maybe Text.empty (\guard -> " if " <> shape guard) (armGuard arm)
    <> "=>" <> shape (armBody arm)

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
literalShape literalValue = case literalValue of
  IntegerValue value -> value
  FloatValue value -> value
  StringValue value -> value
  CharValue value -> Text.singleton value
  BoolValue value -> if value then "true" else "false"
  NullValue -> "null"
