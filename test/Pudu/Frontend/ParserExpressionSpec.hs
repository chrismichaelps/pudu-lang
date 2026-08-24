module Pudu.Frontend.ParserExpressionSpec (parserExpressionProperties) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Diagnostic
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticSpan
  )
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Expression (parseExpression)
import Pudu.Frontend.Parser.State (Parser, expectSymbol, peekKind, runParser)
import Pudu.Frontend.Syntax
  ( Block (..)
  , Expression (..)
  , FieldInit (..)
  , FieldPattern (..)
  , Function (..)
  , Parameter (..)
  , Literal (..)
  , Located (..)
  , MatchArm (..)
  , Pattern (..)
  , moduleNameText
  )
import Pudu.Frontend.Token (Token (tokenSpan), TokenKind (..))
import Pudu.Source (SourceName (SourceName), mergeSpans, newSource, spanStart, unOffset)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

parserExpressionProperties :: [(String, IO Property)]
parserExpressionProperties =
  [ ("binary precedence and associativity are explicit", testPrecedence)
  , ("closed binary vocabulary parses exhaustively", testBinaryVocabulary)
  , ("literal vocabulary maps into expression nodes", testLiterals)
  , ("function literals parse in both body forms", testLambdas)
  , ("postfix calls and members bind before binary operators", testPostfix)
  , ("unary borrow and conditional blocks preserve structure", testUnaryIf)
  , ("expression recovery emits exact diagnostics", testRecovery)
  , ("reserved keywords produce E1041 with guidance", testReservedKeywords)
  , ("index failure-propagation and await postfix forms parse", testPostfixForms)
  , ("match while loop and for parse as expressions", testControlExpressions)
  , ("tuples and record constructions parse", testAggregates)
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
        "<<", ">>", "^", "|", "+", "-", "&+", "&-", "+|", "-|", "*", "/", "%", "&*", "*|"]
  results <- traverse (\operator -> parse ("a " <> operator <> " b")) operators
  pure (map validShape results === map (\operator -> "(a" <> operator <> "b)") operators)

testLiterals :: IO Property
testLiterals = do
  results <- traverse parse ["1", "1.5", "\"hi\"", "'x'", "true", "false", "null"]
  pure (map validShape results === ["1", "1.5", "hi", "x", "true", "false", "null"])

{-| The `fn` keyword introduces a literal wherever an expression may start. It
    is the same spelling the function *type* already uses, and it could not
    previously begin an expression, so nothing became ambiguous. -}
testLambdas :: IO Property
testLambdas = do
  arrow <- parse "fn(x) => x + 1"
  block <- parse "fn(x: Int) -> Int {}"
  empty <- parse "fn() => 1"
  several <- parse "fn(a, b) => a"
  asynchronous <- parse "async fn(x) => x"
  applied <- parse "items.map(fn(x) => x)"
  missingBody <- codes <$> parse "fn(x) x"
  pure $ conjoin
    [ counterexample "an arrow body parses" (validShape arrow === "fn(x)")
    , counterexample "a block body parses" (validShape block === "fn(x)")
    , counterexample "no parameters parses" (validShape empty === "fn()")
    , counterexample "several parameters parse" (validShape several === "fn(a,b)")
    , counterexample "an async literal parses" (validShape asynchronous === "fn(x)")
    , counterexample "a literal is an ordinary argument" (validShape applied === "items.map(fn(x))")
    , counterexample "a missing body names both forms" (missingBody === ["E1032"])
    ]

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

testAggregates :: IO Property
testAggregates = do
  tuple <- parse "(1, 2, 3)"
  grouped <- parse "(1 + 2)"
  record <- parse "User{id: 1, name: n}"
  shorthand <- parse "User{id, name}"
  qualified <- parse "Core.User{id: 1}"
  nested <- parse "Wrapper{inner: User{id: 2}}"
  blockNotRecord <- parse "if READY {} else {}"
  parenthesized <- parse "if (User{id: 1}).id > 0 {} else {}"
  pure $ conjoin
    [ validShape tuple === "(1,2,3)"
    , counterexample "one member without a comma groups" (validShape grouped === "(1+2)")
    , validShape record === "User{id:1,name:n}"
    , counterexample "a field without a value is shorthand"
        (validShape shorthand === "User{id,name}")
    , validShape qualified === "Core.User{id:1}"
    , validShape nested === "Wrapper{inner:User{id:2}}"
    , counterexample "a condition keeps its block"
        (validShape blockNotRecord === "if")
    , counterexample "parentheses reinstate a record construction"
        (validShape parenthesized === "if")
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

helps :: (Located Expression, TokenKind, [Diagnostic]) -> [Text]
helps (_, _, diagnostics) = map (maybe Text.empty id . diagnosticHelp) diagnostics

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
  LambdaExpression value ->
    "fn(" <> Text.intercalate "," (map (locatedValue . parameterName . locatedValue) (functionParameters value)) <> ")"
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
  TupleExpression members -> "(" <> Text.intercalate "," (map shape members) <> ")"
  ArrayExpression members -> "[" <> Text.intercalate "," (map shape members) <> "]"
  UnsafeExpression _ _ -> "unsafe"
  ScopeExpression _ -> "scope"
  MacroCall name arguments ->
    locatedValue name <> "!(" <> Text.intercalate "," (map shape arguments) <> ")"
  RecordExpression path fields ->
    moduleNameText path <> "{" <> Text.intercalate "," (map fieldInitShape fields) <> "}"
  InvalidExpression -> "invalid"

fieldInitShape :: Located FieldInit -> Text
fieldInitShape (Located _ field) =
  locatedValue (fieldInitName field)
    <> maybe Text.empty (\value -> ":" <> shape value) (fieldInitValue field)

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
