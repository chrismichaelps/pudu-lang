{-| @Repl.Outline.Module — renders parsed structure compactly -}
module Pudu.Repl.Outline
  ( outlineBlock
  , outlineExpression
  , outlinePattern
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Capability (..)
  , Declaration (..)
  , Expression (..)
  , FieldPattern (..)
  , FieldInit (..)
  , Function (..)
  , Macro (..)
  , Literal (..)
  , MatchArm (..)
  , Pattern (..)
  , Statement (..)
  , TypeDeclarationValue (..)
  )

{-| Render a parsed block as one line per statement. The shape is structural:
    it shows how the parser grouped the input, which is what a reader asks for
    when the answer surprises them. -}
outlineBlock :: Located Block -> [Text]
outlineBlock (Located _ block) =
  map outlineStatement (blockStatements block)
    <> maybe [] (\value -> ["result " <> outlineExpression value]) (blockResult block)

outlineStatement :: Located Statement -> Text
outlineStatement (Located _ statement) = case statement of
  DeclarationStatement declaration -> outlineDeclaration declaration
  ExpressionStatement expression -> outlineExpression expression
  ReturnStatement Nothing -> "return"
  ReturnStatement (Just expression) -> "return " <> outlineExpression expression
  BreakStatement -> "break"
  ContinueStatement -> "continue"
  InvalidStatement -> "invalid"

outlineDeclaration :: Located Declaration -> Text
outlineDeclaration (Located _ declaration) = case declaration of
  BindingDeclaration _ _ name _ value ->
    "bind " <> locatedValue name <> " = " <> outlineExpression value
  FunctionDeclaration value -> "fn " <> locatedValue (functionName value)
  TypeDeclaration value -> "type " <> locatedValue (typeName value)
  TraitDeclaration _ -> "trait"
  ImplDeclaration _ -> "impl"
  MacroDeclaration value -> "macro " <> locatedValue (macroName value)
  InvalidDeclaration -> "invalid"

outlineExpression :: Located Expression -> Text
outlineExpression (Located _ expression) = case expression of
  LiteralExpression literal -> outlineLiteral literal
  NameExpression names -> Text.intercalate "." (NonEmpty.toList names)
  UnaryExpression operator operand -> "(" <> operator <> outlineExpression operand <> ")"
  BinaryExpression left operator right ->
    "(" <> outlineExpression left <> " " <> operator <> " " <> outlineExpression right <> ")"
  CallExpression callee arguments ->
    outlineExpression callee
      <> "(" <> Text.intercalate ", " (map outlineExpression arguments) <> ")"
  MemberExpression target member -> outlineExpression target <> "." <> locatedValue member
  IndexExpression target index ->
    outlineExpression target <> "[" <> outlineExpression index <> "]"
  TryExpression target -> outlineExpression target <> "?"
  AwaitExpression target -> outlineExpression target <> ".await"
  TupleExpression members -> "(" <> Text.intercalate ", " (map outlineExpression members) <> ")"
  ArrayExpression members -> "[" <> Text.intercalate ", " (map outlineExpression members) <> "]"
  MacroCall name arguments ->
    locatedValue name <> "!(" <> Text.intercalate ", " (map outlineExpression arguments) <> ")"
  UnsafeExpression capabilities body ->
    "unsafe" <> capabilityAnnotation capabilities
      <> " { " <> Text.intercalate "; " (outlineBlock body) <> " }"
  RecordExpression path fields ->
    moduleNameText path <> "{" <> Text.intercalate ", " (map outlineFieldInit fields) <> "}"
  BlockExpression block -> "{ " <> Text.intercalate "; " (outlineBlock block) <> " }"
  IfExpression condition _ elseBranch ->
    "if " <> outlineExpression condition
      <> maybe Text.empty (const " else ...") elseBranch
  MatchExpression scrutinee arms ->
    "match " <> outlineExpression scrutinee
      <> " { " <> Text.intercalate "; " (map outlineArm arms) <> " }"
  WhileExpression condition _ -> "while " <> outlineExpression condition
  LoopExpression _ -> "loop"
  ForExpression binder iterated _ ->
    "for " <> outlinePattern binder <> " in " <> outlineExpression iterated
  InvalidExpression -> "invalid"

outlineFieldInit :: Located FieldInit -> Text
outlineFieldInit (Located _ field) =
  locatedValue (fieldInitName field)
    <> maybe Text.empty (\value -> ": " <> outlineExpression value) (fieldInitValue field)

capabilityAnnotation :: [Located Capability] -> Text
capabilityAnnotation capabilities
  | null capabilities = Text.empty
  | otherwise = "(" <> Text.intercalate ", " (map (outlineCapability . locatedValue) capabilities) <> ")"

outlineCapability :: Capability -> Text
outlineCapability capability = case capability of
  RawCapability -> "raw"
  ForeignCapability -> "foreign"
  UncheckedCapability -> "unchecked"
  NullCapability -> "null"

outlineArm :: Located MatchArm -> Text
outlineArm (Located _ arm) =
  "case " <> outlinePattern (armPattern arm)
    <> maybe Text.empty (\guard -> " if " <> outlineExpression guard) (armGuard arm)
    <> " => " <> outlineExpression (armBody arm)

outlinePattern :: Located Pattern -> Text
outlinePattern (Located _ pattern') = case pattern' of
  WildcardPattern -> "_"
  BindingPattern name -> locatedValue name
  LiteralPattern literal -> outlineLiteral literal
  RangePattern lower inclusive upper ->
    outlineLiteral lower <> (if inclusive then "..=" else "..") <> outlineLiteral upper
  TuplePattern members -> "(" <> Text.intercalate ", " (map outlinePattern members) <> ")"
  ConstructorPattern path arguments ->
    moduleNameText path
      <> if null arguments
           then Text.empty
           else "(" <> Text.intercalate ", " (map outlinePattern arguments) <> ")"
  RecordPattern path fields rest ->
    maybe Text.empty moduleNameText path
      <> "{" <> Text.intercalate ", " (map outlineField fields)
      <> (if rest then ", .." else Text.empty) <> "}"
  AlternativePattern alternatives ->
    Text.intercalate " | " (map outlinePattern alternatives)
  InvalidPattern -> "invalid"

outlineField :: Located FieldPattern -> Text
outlineField (Located _ field) =
  locatedValue (fieldPatternName field)
    <> maybe Text.empty (\value -> ": " <> outlinePattern value) (fieldPatternValue field)

outlineLiteral :: Literal -> Text
outlineLiteral literal = case literal of
  IntegerValue value -> value
  FloatValue value -> value
  StringValue value -> "\"" <> value <> "\""
  CharValue value -> "'" <> Text.singleton value <> "'"
  BoolValue value -> if value then "true" else "false"
  NullValue -> "null"
