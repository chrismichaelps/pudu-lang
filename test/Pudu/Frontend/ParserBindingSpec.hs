module Pudu.Frontend.ParserBindingSpec (parserBindingProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText, diagnosticSpan)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Declaration.Binding (parseLocalBinding, parseTopConst)
import Pudu.Frontend.Parser.State (Parser, expectSymbol, peekKind, runParser)
import Pudu.Frontend.Syntax
  ( Block (..)
  , BindingKind (..)
  , Declaration (..)
  , Expression (..)
  , Literal (..)
  , Located (..)
  , TypeSyntax (..)
  , Visibility (..)
  )
import qualified Pudu.Frontend.Syntax as Syntax
import Pudu.Frontend.Token (Token (tokenSpan), TokenKind (..))
import Pudu.Source (SourceName (SourceName), mergeSpans, newSource, spanEnd, spanStart, unOffset)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

type Parsed = (Located Declaration, TokenKind, [Diagnostic])

parserBindingProperties :: [(String, IO Property)]
parserBindingProperties =
  [ ("module constants preserve visibility and syntax", testTopConstForms)
  , ("module scope admits only const", testModuleScopeClosure)
  , ("local bindings map keywords to mutability policy", testLocalForms)
  , ("binding names enforce their exact name class", testNameClasses)
  , ("missing = diagnoses without consuming the value", testMissingEquals)
  , ("missing initializers recover through the expression parser", testMissingInitializer)
  , ("unadmitted local keywords recover without cascade", testUnadmittedKeyword)
  , ("hostile initializers report only the shared budget", testHostileInitializer)
  ]

testTopConstForms :: IO Property
testTopConstForms = do
  bare <- parseTop Private "const MAX = 10"
  exported <- parseTop Exported "const MAX_SIZE: Int = 10"
  pure $ conjoin
    [ shape bare === "private|comptime|MAX||10"
    , shape exported === "exported|comptime|MAX_SIZE|Int|10"
    , spanOffsets exported === (0, 24)
    , codes exported === []
    ]

testModuleScopeClosure :: IO Property
testModuleScopeClosure = do
  moduleLet <- parseTop Private "let value = 1"
  moduleVar <- parseTop Private "var value = 1"
  pure $ conjoin
    [ counterexample "module let codes" (codes moduleLet === ["E1001"])
    , counterexample "module var codes" (codes moduleVar === ["E1001"])
    , counterexample "module let is rejected once" (diagnosticOffsets moduleLet === [0])
    , shape moduleLet === "invalid"
    , counterexample "rejection makes progress"
        (remainingKind moduleLet === Identifier "value")
    ]

testLocalForms :: IO Property
testLocalForms = do
  immutable <- parseLocal "let count = 1"
  mutable <- parseLocal "var count: Int = 1"
  comptime <- parseLocal "const LIMIT = 1"
  pure $ conjoin
    [ shape immutable === "private|let|count||1"
    , shape mutable === "private|var|count|Int|1"
    , shape comptime === "private|comptime|LIMIT||1"
    , spanOffsets mutable === (0, 18)
    ]

testNameClasses :: IO Property
testNameClasses = do
  upperLocal <- parseLocal "let Total = 1"
  discardLocal <- parseLocal "var _ = 1"
  lowerConstant <- parseLocal "const limit = 1"
  mixedConstant <- parseTop Private "const Max_Size = 1"
  underscoreLocal <- parseLocal "let _unused = 1"
  unicodeLocal <- parseLocal "let \233tape = 1"
  digitConstant <- parseTop Private "const HTTP_2 = 1"
  pure $ conjoin
    [ counterexample "underscore prefix is admitted" (shape underscoreLocal === "private|let|_unused||1")
    , counterexample "lowercase Unicode is admitted" (shape unicodeLocal === "private|let|\233tape||1")
    , counterexample "digits are admitted in constants" (shape digitConstant === "private|comptime|HTTP_2||1")
    , counterexample "uppercase local" (codes upperLocal === ["E1012"])
    , counterexample "discard local" (codes discardLocal === ["E1012"])
    , counterexample "lowercase constant" (codes lowerConstant === ["E1013"])
    , counterexample "mixed constant" (codes mixedConstant === ["E1013"])
    , counterexample "name diagnostics do not cascade"
        (diagnosticOffsets lowerConstant === [6])
    ]

testMissingEquals :: IO Property
testMissingEquals = do
  result <- parseLocal "let count 1"
  pure $ conjoin
    [ codes result === ["E1001"]
    , diagnosticOffsets result === [10]
    , counterexample "value token is preserved" (remainingKind result === IntegerLiteral "1")
    , shape result === "private|let|count||invalid"
    ]

testMissingInitializer :: IO Property
testMissingInitializer = do
  result <- parseLocal "let count ="
  pure $ conjoin
    [ codes result === ["E1040"]
    , shape result === "private|let|count||invalid"
    , remainingKind result === EndOfFile
    ]

testUnadmittedKeyword :: IO Property
testUnadmittedKeyword = do
  result <- parseLocal "return 1"
  pure $ conjoin
    [ codes result === ["E1001"]
    , diagnosticOffsets result === [0]
    , shape result === "invalid"
    , counterexample "recovery makes progress" (remainingKind result === IntegerLiteral "1")
    ]

testHostileInitializer :: IO Property
testHostileInitializer = do
  let input = "let deep = " <> Text.concat (replicate 520 "-") <> "1"
  result <- parseLocal input
  pure $ conjoin
    [ counterexample "budget is reported once" (codes result === ["E1099"])
    , diagnosticOffsets result === [523]
    , counterexample "the binding node survives budget exhaustion"
        (Text.take 18 (shape result) === "private|let|deep||")
    ]

parseTop :: Visibility -> Text -> IO Parsed
parseTop visibility = parseWith (parseTopConst visibility emptyBlock)

parseLocal :: Text -> IO Parsed
parseLocal = parseWith (parseLocalBinding emptyBlock)

parseWith :: Parser (Located Declaration) -> Text -> IO Parsed
parseWith action input = do
  source <- newSource (SourceName "binding.pudu") input
  let LexResult{lexTokens} = lexSource source
      combined = (,) <$> action <*> peekKind
      ((declaration, remaining), diagnostics) = runParser source combined lexTokens
  pure (declaration, remaining, diagnostics)

emptyBlock :: Parser (Located Block)
emptyBlock = do
  opening <- expectSymbol "{" "to start the block"
  closing <- expectSymbol "}" "to close the block"
  let spanValue = maybe (tokenSpan opening) id (mergeSpans (tokenSpan opening) (tokenSpan closing))
  pure (Located spanValue (Block [] Nothing))

codes :: Parsed -> [Text]
codes (_, _, diagnostics) = map (diagnosticCodeText . diagnosticCode) diagnostics

diagnosticOffsets :: Parsed -> [Int]
diagnosticOffsets (_, _, diagnostics) = map (unOffset . spanStart . diagnosticSpan) diagnostics

remainingKind :: Parsed -> TokenKind
remainingKind (_, kind, _) = kind

spanOffsets :: Parsed -> (Int, Int)
spanOffsets (Located spanValue _, _, _) = (unOffset (spanStart spanValue), unOffset (spanEnd spanValue))

shape :: Parsed -> Text
shape (Located _ declaration, _, _) = case declaration of
  BindingDeclaration visibility bindingKind name annotation value ->
    Text.intercalate "|"
      [ visibilityText visibility
      , bindingKindText bindingKind
      , locatedValue name
      , maybe Text.empty typeShape annotation
      , expressionShape value
      ]
  InvalidDeclaration -> "invalid"
  _ -> "other"

visibilityText :: Visibility -> Text
visibilityText visibility = case visibility of
  Private -> "private"
  Exported -> "exported"

bindingKindText :: BindingKind -> Text
bindingKindText bindingKind = case bindingKind of
  Immutable -> "let"
  Mutable -> "var"
  CompileTime -> "comptime"

typeShape :: Located TypeSyntax -> Text
typeShape (Located _ typeValue) = case typeValue of
  NamedType moduleName arguments ->
    Syntax.moduleNameText moduleName
      <> if null arguments
           then Text.empty
           else "<" <> Text.intercalate "," (map typeShape arguments) <> ">"
  ReferenceType mutable target -> (if mutable then "&mut " else "&") <> typeShape target
  TupleType members -> "(" <> Text.intercalate "," (map typeShape members) <> ")"
  UnitType -> "()"
  InvalidType -> "invalid"
  _ -> "other"

expressionShape :: Located Expression -> Text
expressionShape (Located _ expression) = case expression of
  LiteralExpression (IntegerValue value) -> value
  LiteralExpression _ -> "literal"
  NameExpression names -> Text.intercalate "." (foldr (:) [] names)
  UnaryExpression operator operand -> "(" <> operator <> expressionShape operand <> ")"
  BinaryExpression left operator right ->
    "(" <> expressionShape left <> operator <> expressionShape right <> ")"
  CallExpression callee arguments ->
    expressionShape callee <> "(" <> Text.intercalate "," (map expressionShape arguments) <> ")"
  MemberExpression target member -> expressionShape target <> "." <> locatedValue member
  BlockExpression _ -> "block"
  IfExpression{} -> "if"
  InvalidExpression -> "invalid"
  _ -> "other"
