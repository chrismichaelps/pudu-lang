{-| @Test.Frontend.ParserExpression.Common — shared expression parser fixtures and AST shapers -}
module Pudu.Frontend.ParserExpression.Common
  ( armShape
  , codes
  , diagnosticOffsets
  , emptyBlock
  , fieldInitShape
  , fieldShape
  , firstOf
  , helps
  , labelShape
  , literalShape
  , parse
  , patternShape
  , remainingOf
  , resultKind
  , shape
  , validShape
  ) where

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
  , Literal (..)
  , Located (..)
  , MatchArm (..)
  , Parameter (..)
  , Pattern (..)
  , moduleNameText
  )
import Pudu.Frontend.Token (Token (tokenSpan), TokenKind (..))
import Pudu.Source (SourceName (SourceName), mergeSpans, newSource, spanStart, unOffset)

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

firstOf :: (Located Expression, TokenKind, [Diagnostic]) -> Located Expression
firstOf (expression, _, _) = expression

remainingOf :: (Located Expression, TokenKind, [Diagnostic]) -> TokenKind
remainingOf (_, remainingKind, _) = remainingKind

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

labelShape :: Maybe (Located Text) -> Text
labelShape = foldMap (\label -> "@" <> locatedValue label <> " ")

shape :: Located Expression -> Text
shape (Located _ expression) = case expression of
  LiteralExpression literalValue -> literalShape literalValue
  NameExpression names -> Text.intercalate "." (NonEmpty.toList names)
  UnaryExpression operator operand -> "(" <> operator <> shape operand <> ")"
  BinaryExpression left operator right -> "(" <> shape left <> operator <> shape right <> ")"
  CallExpression callee arguments -> shape callee <> "(" <> Text.intercalate "," (map shape arguments) <> ")"
  TypeApplication target arguments ->
    shape target <> "[" <> Text.intercalate "," (map (const "T") arguments) <> "]"
  LambdaExpression value ->
    "fn(" <> Text.intercalate "," (map (locatedValue . parameterName . locatedValue) (functionParameters value)) <> ")"
  MemberExpression target member -> shape target <> "." <> locatedValue member
  IndexExpression target index -> shape target <> "[" <> shape index <> "]"
  TryExpression target -> shape target <> "?"
  AwaitExpression target -> shape target <> ".await"
  BlockExpression _ -> "block"
  IfExpression{} -> "if"
  IfLetExpression pattern' subject _ elseBranch ->
    "if let " <> patternShape pattern' <> " = " <> shape subject
      <> maybe Text.empty (const " else") elseBranch
  MatchExpression scrutinee arms ->
    "match(" <> shape scrutinee <> "){"
      <> Text.intercalate ";" (map armShape arms) <> "}"
  WhileExpression label condition _ -> labelShape label <> "while(" <> shape condition <> ")"
  WhileLetExpression label pattern' subject _ ->
    labelShape label <> "while let " <> patternShape pattern' <> "=" <> shape subject
  LoopExpression label _ -> labelShape label <> "loop"
  ForExpression label binder iterated _ ->
    labelShape label <> "for " <> patternShape binder <> " in " <> shape iterated
  TupleExpression members -> "(" <> Text.intercalate "," (map shape members) <> ")"
  ArrayExpression members -> "[" <> Text.intercalate "," (map shape members) <> "]"
  SetExpression members -> "#{" <> Text.intercalate "," (map shape members) <> "}"
  UnsafeExpression _ _ -> "unsafe"
  ScopeExpression _ -> "scope"
  MacroCall name arguments ->
    locatedValue name <> "!(" <> Text.intercalate "," (map shape arguments) <> ")"
  RecordExpression path fields ->
    moduleNameText path <> "{" <> Text.intercalate "," (map fieldInitShape fields) <> "}"
  RecordUpdateExpression path source fields ->
    moduleNameText path <> "{.." <> shape source
      <> "," <> Text.intercalate "," (map fieldInitShape fields) <> "}"
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
  DecimalValue value -> value
  StringValue value -> value
  CharValue value -> Text.singleton value
  BoolValue value -> if value then "true" else "false"
  NullValue -> "null"
