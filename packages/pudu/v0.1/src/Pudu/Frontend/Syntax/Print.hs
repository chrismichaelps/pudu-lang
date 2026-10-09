{-| @Program.Syntax.Print — renders checked syntax back to Pudu source.

    Generated declarations have no text of their own, so a reader asking what a
    derive produced needs one written for them. Every compound operand is
    parenthesized: the tree records structure, not the precedence the text was
    read with, and a redundant pair of parentheses never changes a meaning.
    Layout is left to the formatter. -}
module Pudu.Frontend.Syntax.Print
  ( printImpl
  , printType
  ) where

import qualified Data.List as List
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Inline (inlineStatements)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree

{-| The module the printed text stands in. A name it declares is written
    bare, as that module's own code writes it; every other name keeps its
    qualification. -}
type Home = ModuleName

printImpl :: Home -> Impl -> Text
printImpl home value =
  "impl" <> typeParameters home (implTypeParams value) <> " " <> typeText home (implTrait value)
    <> " for " <> typeText home (implTarget value) <> constraints home (implConstraints value) <> " {\n"
    <> Text.concat [indent 1 (function home (locatedValue method)) <> "\n" | method <- implFunctions value]
    <> "}\n"

function :: Home -> Function -> Text
function home value =
  (if functionAsync value then "async " else "")
    <> "fn " <> locatedValue (functionName value) <> typeParameters home (functionTypeParams value)
    <> signature home value <> body (functionBody value)
 where
  body Nothing = ""
  body (Just (Located _ (BlockBody held))) = " " <> block home 0 (locatedValue held)
  body (Just (Located _ (ExpressionBody held))) = " = " <> expression home 0 held

signature :: Home -> Function -> Text
signature home value =
  "(" <> commaSeparated (map (parameter . locatedValue) (functionParameters value)) <> ")"
    <> maybe "" ((" -> " <>) . typeText home) (functionReturn value)
    <> constraints home (functionConstraints value)
 where
  parameter held =
    locatedValue (parameterName held)
      <> maybe "" ((": " <>) . typeText home) (parameterType held)
      <> maybe "" ((" = " <>) . expression home 0) (parameterDefault held)

typeParameters :: Home -> [Located TypeParam] -> Text
typeParameters _ [] = ""
typeParameters home parameters = "[" <> commaSeparated (map (one . locatedValue) parameters) <> "]"
 where
  one held =
    locatedValue (typeParamName held)
      <> (if typeParamArity held > 0
            then "[" <> commaSeparated (replicate (typeParamArity held) "_") <> "]" else "")
      <> bounds home (typeParamBounds held)

constraints :: Home -> [Located Constraint] -> Text
constraints _ [] = ""
constraints home written = " where " <> commaSeparated (map (one . locatedValue) written)
 where
  one held = locatedValue (constraintSubject held) <> bounds home (constraintBounds held)

bounds :: Home -> [Located TypeSyntax] -> Text
bounds _ [] = ""
bounds home written = ": " <> Text.intercalate " + " (map (typeText home) written)

printType :: Home -> Located TypeSyntax -> Text
printType = typeText

typeText :: Home -> Located TypeSyntax -> Text
typeText home (Located _ written) = case written of
  NamedType path [] -> pathText home path
  NamedType path arguments -> pathText home path <> "[" <> commaSeparated (map (typeText home) arguments) <> "]"
  DynamicType path -> "dynamic " <> pathText home path
  ReferenceType mutable target -> (if mutable then "&mut " else "&") <> typeText home target
  TupleType members -> "(" <> commaSeparated (map (typeText home) members) <> ")"
  FunctionType async inputs result ->
    (if async then "async " else "") <> "fn(" <> commaSeparated (map (typeText home) inputs) <> ") -> " <> typeText home result
  UnsafeType capabilities target -> "unsafe(" <> capabilityList capabilities <> ") " <> typeText home target
  UnitType -> "()"
  InvalidType -> "_"

capabilityList :: [Located Capability] -> Text
capabilityList = commaSeparated . map (capability . locatedValue)
 where
  capability held = case held of
    RawCapability -> "raw"
    ForeignCapability -> "foreign"
    UncheckedCapability -> "unchecked"
    NullCapability -> "null"

block :: Home -> Int -> Block -> Text
block home depth value = case (inlineStatements (blockStatements value), blockResult value) of
  ([], Nothing) -> "{}"
  (statements, result) ->
    "{\n"
      <> Text.concat [indent (depth + 1) (statement home (depth + 1) (locatedValue held)) <> "\n" | held <- statements]
      <> maybe "" (\held -> indent (depth + 1) (expression home (depth + 1) held) <> "\n") result
      <> indent depth "}"

statement :: Home -> Int -> Statement -> Text
statement home depth value = case value of
  DeclarationStatement (Located _ declaration) -> case declaration of
    BindingDeclaration _ kind name written initial ->
      binding kind <> " " <> locatedValue name <> maybe "" ((": " <>) . typeText home) written
        <> " = " <> expression home depth initial
    FunctionDeclaration held -> function home held
    _ -> "/* declaration */"
  ExpressionStatement held -> expression home depth held
  ReturnStatement held -> "return" <> maybe "" ((" " <>) . expression home depth) held
  BreakStatement label held -> "break" <> maybe "" ((" @" <>) . locatedValue) label <> maybe "" ((" " <>) . expression home depth) held
  ContinueStatement label -> "continue" <> maybe "" ((" @" <>) . locatedValue) label
  LetElseStatement pat held fallback ->
    "let " <> pattern home pat <> " = " <> expression home depth held <> " else " <> block home depth (locatedValue fallback)
  LetPatternStatement kind pat written held ->
    binding kind <> " " <> pattern home pat <> maybe "" ((": " <>) . typeText home) written <> " = " <> expression home depth held
  InvalidStatement -> "/* invalid */"
 where
  binding kind = case kind of
    Immutable -> "let"
    Mutable -> "var"
    CompileTime -> "const"

expression :: Home -> Int -> Located Expression -> Text
expression home depth (Located at value) = case value of
  LiteralExpression held -> literal held
  NameExpression path -> pathText home (ModuleName path)
  UnaryExpression operator held -> operator <> (if operator == "&mut" then " " else "") <> operand held
  BinaryExpression left operator right -> operand left <> " " <> operator <> " " <> operand right
  CallExpression callee arguments -> operand callee <> "(" <> commaSeparated (map recurse arguments) <> ")"
  MemberExpression target member -> operand target <> "." <> locatedValue member
  IndexExpression target index -> operand target <> "[" <> recurse index <> "]"
  RangeExpression from inclusive to ->
    maybe "" operand from <> (if inclusive then "..=" else "..") <> maybe "" operand to
  TryExpression held -> operand held <> "?"
  AwaitExpression held -> operand held <> ".await"
  TupleExpression [] -> "()"
  TupleExpression [only] -> "(" <> recurse only <> ",)"
  TupleExpression members -> "(" <> commaSeparated (map recurse members) <> ")"
  ArrayExpression members -> "[" <> commaSeparated (map recurse members) <> "]"
  SetExpression members -> "#{" <> commaSeparated (map recurse members) <> "}"
  UnsafeExpression capabilities held -> "unsafe(" <> capabilityList capabilities <> ") " <> nested held
  MacroCall name arguments -> locatedValue name <> "!(" <> commaSeparated (map recurse arguments) <> ")"
  ScopeExpression held -> "async with scope " <> nested held
  LambdaExpression held -> "fn" <> signature home held <> lambdaBody (functionBody held)
  -- A selection checking applied shares its callee's span; nobody wrote it.
  TypeApplication held _ | locatedSpan held == at -> recurse held
  TypeApplication held arguments -> operand held <> "[" <> commaSeparated (map (typeText home) arguments) <> "]"
  RecordExpression path fields -> pathText home path <> "{" <> commaSeparated (map field fields) <> "}"
  RecordUpdateExpression path base fields ->
    pathText home path <> "{.." <> recurse base <> Text.concat (map ((", " <>) . field) fields) <> "}"
  BlockExpression held -> nested held
  IfExpression condition success failure ->
    "if " <> operand condition <> " " <> nested success <> maybe "" ((" else " <>) . alternative) failure
  IfLetExpression pat subject success failure ->
    "if let " <> pattern home pat <> " = " <> operand subject <> " " <> nested success
      <> maybe "" ((" else " <>) . alternative) failure
  MatchExpression subject arms ->
    "match " <> operand subject <> " {\n"
      <> Text.concat [indent (depth + 1) (arm (locatedValue held)) <> "\n" | held <- arms]
      <> indent depth "}"
  WhileExpression label condition body -> labelled label <> "while " <> recurse condition <> " " <> nested body
  WhileLetExpression label pat subject body ->
    labelled label <> "while let " <> pattern home pat <> " = " <> recurse subject <> " " <> nested body
  LoopExpression label body -> labelled label <> "loop " <> nested body
  ForExpression label pat subject body ->
    labelled label <> "for " <> pattern home pat <> " in " <> recurse subject <> " " <> nested body
  ComptimeForExpression loop ->
    "comptime for " <> locatedValue (comptimeForElement loop) <> ": " <> typeText home (comptimeForType loop)
      <> " in " <> recurse (comptimeForSource loop) <> constraints home (comptimeForConstraints loop)
      <> " " <> nested (comptimeForBody loop)
  InvalidExpression -> "/* invalid */"
 where
  recurse = expression home depth
  operand held
    | atomic (locatedValue held) = recurse held
    | otherwise = "(" <> recurse held <> ")"
  nested (Located _ held) = block home depth held
  alternative held@(Located _ inner) = case inner of
    IfExpression {} -> recurse held
    IfLetExpression {} -> recurse held
    BlockExpression body -> nested body
    _ -> "{ " <> recurse held <> " }"
  labelled = maybe "" (\name -> "@" <> locatedValue name <> " ")
  field (Located _ held) = locatedValue (fieldInitName held) <> maybe "" ((": " <>) . recurse) (fieldInitValue held)
  arm held =
    "case " <> pattern home (armPattern held) <> maybe "" ((" if " <>) . expression home (depth + 1)) (armGuard held)
      <> " => " <> expression home (depth + 1) (armBody held)
  lambdaBody Nothing = ""
  lambdaBody (Just (Located _ (BlockBody held))) = " " <> nested held
  lambdaBody (Just (Located _ (ExpressionBody held))) = " = " <> recurse held

{-| An expression that never needs parentheses as an operand. -}
atomic :: Expression -> Bool
atomic value = case value of
  LiteralExpression _ -> True
  NameExpression _ -> True
  CallExpression {} -> True
  MemberExpression {} -> True
  IndexExpression {} -> True
  TryExpression _ -> True
  AwaitExpression _ -> True
  TupleExpression _ -> True
  ArrayExpression _ -> True
  SetExpression _ -> True
  MacroCall {} -> True
  TypeApplication {} -> True
  RecordExpression {} -> True
  RecordUpdateExpression {} -> True
  _ -> False

pattern :: Home -> Located Pattern -> Text
pattern home (Located _ value) = case value of
  WildcardPattern -> "_"
  BindingPattern name -> locatedValue name
  LiteralPattern held -> literal held
  RangePattern from inclusive to -> literal from <> (if inclusive then "..=" else "..") <> literal to
  TuplePattern members -> "(" <> commaSeparated (map (pattern home) members) <> ")"
  ArrayPattern prefix rest suffix ->
    "[" <> commaSeparated (map (pattern home) prefix <> maybe [] (pure . restText) rest <> map (pattern home) suffix) <> "]"
  ConstructorPattern path [] -> pathText home path
  ConstructorPattern path members -> pathText home path <> "(" <> commaSeparated (map (pattern home) members) <> ")"
  RecordPattern path fields rest ->
    maybe "" (pathText home) path <> "{"
      <> commaSeparated (map fieldPattern fields <> (if rest then [".."] else [])) <> "}"
  AlternativePattern alternatives -> Text.intercalate " | " (map (pattern home) alternatives)
  InvalidPattern -> "_"
 where
  restText rest = case rest of
    IgnoredRest _ -> ".."
    BoundRest name -> ".." <> locatedValue name
  fieldPattern (Located _ held) =
    locatedValue (fieldPatternName held) <> maybe "" ((": " <>) . pattern home) (fieldPatternValue held)

literal :: Literal -> Text
literal value = case value of
  IntegerValue text -> text
  ResolvedInteger _ number -> Text.pack (show number)
  FloatValue text -> text
  DecimalValue text -> text
  StringValue text -> "\"" <> Text.concatMap escape text <> "\""
  CharValue character -> "'" <> escapeChar character <> "'"
  BoolValue flag -> if flag then "true" else "false"
  NullValue -> "null"
 where
  escape character = case character of
    '{' -> "\\{"
    '}' -> "\\}"
    '"' -> "\\\""
    _ -> escapeChar character
  escapeChar character = case character of
    '\\' -> "\\\\"
    '\n' -> "\\n"
    '\t' -> "\\t"
    '\r' -> "\\r"
    '\'' -> "\\'"
    _ -> Text.singleton character

commaSeparated :: [Text] -> Text
commaSeparated = Text.intercalate ", "

indent :: Int -> Text -> Text
indent depth = (Text.replicate (2 * depth) " " <>)

pathText :: Home -> ModuleName -> Text
pathText home path = case List.stripPrefix (NonEmpty.toList (moduleNameSegments home)) (NonEmpty.toList (moduleNameSegments path)) of
  Just rest@(_ : _) -> Text.intercalate "." rest
  _ -> moduleNameText path
