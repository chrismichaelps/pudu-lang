module Pudu.Frontend.ParserBlockSpec (parserBlockProperties) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText, diagnosticSpan)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Declaration.Block (parseBlock)
import Pudu.Frontend.Parser.State (peekKind, runParser)
import Pudu.Frontend.Syntax
  ( BindingKind (..)
  , Block (..)
  , Declaration (..)
  , Expression (..)
  , Literal (..)
  , Located (..)
  , Statement (..)
  )
import Pudu.Frontend.Token (TokenKind (..))
import Pudu.Source (SourceName (SourceName), newSource, spanEnd, spanStart, unOffset)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

type Parsed = (Located Block, TokenKind, [Diagnostic])

parserBlockProperties :: [(String, IO Property)]
parserBlockProperties =
  [ ("blocks order statements and promote a trailing expression", testBlockShape)
  , ("line breaks separate statements without punctuation", testStatementBoundaries)
  , ("operators and leading dots continue one statement without ambiguity", testContinuation)
  , ("return carries a value only on its own line", testReturnStatements)
  , ("nested blocks resolve the parser recursion", testNesting)
  , ("unclosed and unrecognized statements recover exactly", testRecovery)
  , ("loops and jumps parse as statements", testLoopStatements)
  , ("a statement ends at the line break", testAdjacentStatements)
  , ("long statement lists stay linear while brace floods share the budget", testHostileBlocks)
  ]

testBlockShape :: IO Property
testBlockShape = do
  empty <- parse "{}"
  bindings <- parse "{\n  let a = 1\n  var b = 2\n  a\n}"
  noResult <- parse "{\n  let a = 1\n}"
  pure $ conjoin
    [ shape empty === "[]"
    , shape bindings === "[let a=1;var b=2]=>a"
    , shape noResult === "[let a=1]"
    , codes bindings === []
    , spanOffsets empty === (0, 2)
    ]

testStatementBoundaries :: IO Property
testStatementBoundaries = do
  separated <- parse "{\n  f()\n  g()\n}"
  lineInitialMinus <- parse "{\n  f()\n  -value\n}"
  lineInitialParen <- parse "{\n  f\n  (x)\n}"
  pure $ conjoin
    [ shape separated === "[f()]=>g()"
    , counterexample "line-initial - starts a statement"
        (shape lineInitialMinus === "[f()]=>(-value)")
    , counterexample "line-initial ( is not a call"
        (shape lineInitialParen === "[f]=>x")
    , codes separated === []
    ]

testContinuation :: IO Property
testContinuation = do
  trailingOperator <- parse "{\n  let total = base +\n    extra\n}"
  leadingOperator <- parse "{\n  let total = 1\n    + 2 * 3\n}"
  leadingDot <- parse "{\n  client\n    .connect()\n    .id\n}"
  sameLine <- parse "{\n  a - b\n}"
  mixedChain <- parse "{\n  let n = 1\n    + 2 * 3\n    - 4\n  n\n}"
  separatedPrefix <- parse "{\n  let n = 1\n    + 2 * 3\n  (-4)\n  n\n}"
  afterBrace <- parse "{\n  while ready {}\n  -1\n}"
  dereference <- parse "{\n  value\n  *borrowed\n}"
  pure $ conjoin
    [ shape trailingOperator === "[let total=(base+extra)]"
    , counterexample "an operator with no prefix form may lead a continuation"
        (shape leadingOperator === "[let total=(1+(2*3))]")
    , shape leadingDot === "[]=>client.connect().id"
    , shape sameLine === "[]=>(a-b)"
    , counterexample "a mixed leading-operator chain cannot silently change value"
        (codes mixedChain === ["E1055"])
    , counterexample "recovery preserves the prefix expression and following statement"
        (shape mixedChain === "[let n=(1+(2*3));(-4)]=>n")
    , counterexample "parentheses explicitly start a new prefix expression"
        ((codes separatedPrefix, shape separatedPrefix)
          === ([], "[let n=(1+(2*3));(-4)]=>n"))
    , counterexample "a brace-terminated construct may be followed by unary minus"
        (codes afterBrace === [])
    , counterexample "an unrelated dereference remains a statement"
        (codes dereference === [])
    , counterexample "ordinary prefix statements keep their block shape"
        ((shape afterBrace, shape dereference)
          === ("[while]=>(-1)", "[value]=>(*borrowed)"))
    , codes leadingOperator === []
    , codes leadingDot === []
    ]

testReturnStatements :: IO Property
testReturnStatements = do
  bare <- parse "{\n  return\n}"
  valued <- parse "{\n  return total\n}"
  bareBeforeStatement <- parse "{\n  return\n  f()\n}"
  pure $ conjoin
    [ shape bare === "[return]"
    , shape valued === "[return total]"
    , counterexample "return does not absorb the next line"
        (shape bareBeforeStatement === "[return]=>f()")
    , codes bareBeforeStatement === []
    ]

testNesting :: IO Property
testNesting = do
  nested <- parse "{\n  let inner = {\n    let a = 1\n    a\n  }\n  inner\n}"
  conditional <- parse "{\n  if flag {\n    a\n  } else {\n    b\n  }\n}"
  pure $ conjoin
    [ shape nested === "[let inner=block]=>inner"
    , shape conditional === "[]=>if"
    , codes nested === []
    , codes conditional === []
    ]

testRecovery :: IO Property
testRecovery = do
  unclosed <- parse "{\n  let a = 1\n"
  unrecognized <- parse "{\n  ,\n  a\n}"
  pure $ conjoin
    [ counterexample "missing brace" (codes unclosed === ["E1000"])
    , shape unclosed === "[let a=1]"
    , counterexample "unrecognized statement" (codes unrecognized === ["E1040"])
    , diagnosticOffsets unrecognized === [4]
    , counterexample "recovery keeps the following statement"
        (shape unrecognized === "[invalid]=>a")
    , remainingKind unrecognized === EndOfFile
    ]

testLoopStatements :: IO Property
testLoopStatements = do
  whileBlock <- parse "{\n  while ready {\n    step()\n  }\n}"
  breakBlock <- parse "{\n  loop {\n    break\n  }\n}"
  continueBlock <- parse "{\n  for item in items {\n    continue\n  }\n}"
  jumps <- parse "{\n  break\n  continue\n}"
  labelledJumps <- parse "{\n  break @outer\n  continue @outer\n}"
  carried <- parse "{\n  break 1\n  break @outer 2\n}"
  bareOnItsLine <- parse "{\n  break\n  1\n}"
  pure $ conjoin
    [ shape whileBlock === "[]=>while"
    , shape breakBlock === "[]=>loop"
    , shape continueBlock === "[]=>for"
    , counterexample "jumps are statements" (shape jumps === "[break;continue]")
    , counterexample "a jump carries the label it names"
        (shape labelledJumps === "[break@outer;continue@outer]")
    , counterexample "a break carries a value with or without a label"
        (shape carried === "[break 1;break@outer 2]")
    , counterexample "a break alone on its line does not swallow the next statement"
        (shape bareOnItsLine === "[break]=>1")
    , codes whileBlock === []
    , codes continueBlock === []
    , codes carried === []
    ]

{-| A newline delimits a statement, so two on one line are not separated. The
    rule stays quiet where recovery has already spoken, which is what keeps a
    hostile file from turning one mistake into hundreds. -}
testAdjacentStatements :: IO Property
testAdjacentStatements = do
  adjacent <- parse "{\n  1 2\n}"
  several <- parse "{\n  1 2 3 4\n}"
  separated <- parse "{\n  1\n  2\n}"
  continued <- parse "{\n  1 +\n    2\n}"
  memberChain <- parse "{\n  value\n    .first\n}"
  pure $ conjoin
    [ counterexample "two statements on one line are reported"
        (codes adjacent === ["E1049"])
    , counterexample "and reported once, however many were crowded on"
        (codes several === ["E1049"])
    , counterexample "separate lines are ordinary" (codes separated === [])
    , counterexample "a continuation is not a second statement"
        (codes continued === [])
    , counterexample "nor is a line opening with a member access"
        (codes memberChain === [])
    ]

testHostileBlocks :: IO Property
testHostileBlocks = do
  statements <- parse ("{" <> Text.concat (replicate 520 "\na") <> "\n}")
  braces <- parse (Text.concat (replicate 520 "{") <> Text.concat (replicate 520 "}"))
  pure $ conjoin
    [ counterexample "long statement lists are ordinary input" (codes statements === [])
    , counterexample "every statement is preserved" (statementCount statements === 519)
    , counterexample "brace flood" (codes braces === ["E1099"])
    ]

statementCount :: Parsed -> Int
statementCount (Located _ (Block statements _), _, _) = length statements

parse :: Text -> IO Parsed
parse input = do
  source <- newSource (SourceName "block.pudu") input
  let LexResult{lexTokens} = lexSource source
      action = (,) <$> parseBlock <*> peekKind
      ((block, remaining), diagnostics) = runParser source action lexTokens
  pure (block, remaining, diagnostics)

codes :: Parsed -> [Text]
codes (_, _, diagnostics) = map (diagnosticCodeText . diagnosticCode) diagnostics

diagnosticOffsets :: Parsed -> [Int]
diagnosticOffsets (_, _, diagnostics) = map (unOffset . spanStart . diagnosticSpan) diagnostics

remainingKind :: Parsed -> TokenKind
remainingKind (_, kind, _) = kind

spanOffsets :: Parsed -> (Int, Int)
spanOffsets (Located spanValue _, _, _) = (unOffset (spanStart spanValue), unOffset (spanEnd spanValue))

shape :: Parsed -> Text
shape (Located _ (Block statements result), _, _) =
  "[" <> Text.intercalate ";" (map statementShape statements) <> "]"
    <> maybe Text.empty (\value -> "=>" <> expressionShape value) result

statementShape :: Located Statement -> Text
statementShape (Located _ statement) = case statement of
  DeclarationStatement declaration -> declarationShape declaration
  ExpressionStatement expression -> expressionShape expression
  ReturnStatement Nothing -> "return"
  ReturnStatement (Just expression) -> "return " <> expressionShape expression
  BreakStatement label value ->
    "break" <> foldMap (\name -> "@" <> locatedValue name) label
      <> foldMap ((" " <>) . expressionShape) value
  ContinueStatement label -> "continue" <> foldMap (\name -> "@" <> locatedValue name) label
  InvalidStatement -> "invalid"

declarationShape :: Located Declaration -> Text
declarationShape (Located _ declaration) = case declaration of
  BindingDeclaration _ bindingKind name _ value ->
    bindingKindText bindingKind <> " " <> locatedValue name <> "=" <> expressionShape value
  InvalidDeclaration -> "invalid"
  _ -> "other"

bindingKindText :: BindingKind -> Text
bindingKindText bindingKind = case bindingKind of
  Immutable -> "let"
  Mutable -> "var"
  CompileTime -> "const"

expressionShape :: Located Expression -> Text
expressionShape (Located _ expression) = case expression of
  LiteralExpression (IntegerValue value) -> value
  LiteralExpression _ -> "literal"
  NameExpression names -> Text.intercalate "." (NonEmpty.toList names)
  UnaryExpression operator operand -> "(" <> operator <> expressionShape operand <> ")"
  BinaryExpression left operator right ->
    "(" <> expressionShape left <> operator <> expressionShape right <> ")"
  CallExpression callee arguments ->
    expressionShape callee <> "(" <> Text.intercalate "," (map expressionShape arguments) <> ")"
  MemberExpression target member -> expressionShape target <> "." <> locatedValue member
  IndexExpression target index -> expressionShape target <> "[" <> expressionShape index <> "]"
  TryExpression target -> expressionShape target <> "?"
  AwaitExpression target -> expressionShape target <> ".await"
  BlockExpression _ -> "block"
  IfExpression{} -> "if"
  MatchExpression{} -> "match"
  WhileExpression{} -> "while"
  LoopExpression{} -> "loop"
  ForExpression{} -> "for"
  InvalidExpression -> "invalid"
  _ -> "other"
