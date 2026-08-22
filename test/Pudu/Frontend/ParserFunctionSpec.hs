module Pudu.Frontend.ParserFunctionSpec (parserFunctionProperties) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText, diagnosticSpan)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Declaration.Function (parseFunction)
import Pudu.Frontend.Parser.State (peekKind, runParser)
import Pudu.Frontend.Syntax
  ( Block (..)
  , Constraint (..)
  , Declaration (..)
  , Function (..)
  , TypeParam (..)
  , Expression (..)
  , FunctionBody (..)
  , Literal (..)
  , Located (..)
  , ModuleName
  , Parameter (..)
  , Statement (..)
  , TypeSyntax (..)
  , Visibility (..)
  , moduleNameText
  )
import Pudu.Frontend.Token (TokenKind (..))
import Pudu.Source (SourceName (SourceName), newSource, spanEnd, spanStart, unOffset)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

type Parsed = (Located Declaration, TokenKind, [Diagnostic])

parserFunctionProperties :: [(String, IO Property)]
parserFunctionProperties =
  [ ("signatures preserve async visibility parameters and return types", testSignatures)
  , ("parameters admit types defaults and one trailing comma", testParameters)
  , ("bodies accept blocks and expression forms", testBodies)
  , ("missing bodies and malformed lists diagnose exactly", testRecovery)
  , ("generic parameters bounds and where clauses parse", testGenerics)
  , ("long parameter lists stay linear while nested defaults share the budget", testHostileParameters)
  ]

testSignatures :: IO Property
testSignatures = do
  bare <- parse Private "fn run() {}"
  exported <- parse Exported "fn size(value: Int) -> Int { value }"
  asynchronous <- parse Private "async fn fetch() -> Response {}"
  pure $ conjoin
    [ shape bare === "private fn run()->_ {}"
    , shape exported === "exported fn size(value:Int)->Int {=>value}"
    , shape asynchronous === "private async fn fetch()->Response {}"
    , codes exported === []
    , spanOffsets bare === (0, 11)
    ]

testParameters :: IO Property
testParameters = do
  multiple <- parse Private "fn add(left: Int, right: Int) -> Int { left }"
  defaults <- parse Private "fn open(path: Text, retries: Int = 3) {}"
  trailing <- parse Private "fn tidy(first: Int,) {}"
  untyped <- parse Private "fn infer(value) {}"
  pure $ conjoin
    [ shape multiple === "private fn add(left:Int,right:Int)->Int {=>left}"
    , shape defaults === "private fn open(path:Text,retries:Int=3)->_ {}"
    , shape trailing === "private fn tidy(first:Int)->_ {}"
    , shape untyped === "private fn infer(value)->_ {}"
    , codes defaults === []
    ]

testBodies :: IO Property
testBodies = do
  expressionBody <- parse Private "fn double(value: Int) -> Int = value * 2"
  statements <- parse Private "fn run() {\n  let a = 1\n  a\n}"
  nextLineBrace <- parse Private "fn run()\n{}"
  pure $ conjoin
    [ shape expressionBody === "private fn double(value:Int)->Int =(value*2)"
    , shape statements === "private fn run()->_ {let a=1=>a}"
    , counterexample "a body brace on the next line still belongs to the function"
        (shape nextLineBrace === "private fn run()->_ {}")
    , codes statements === []
    ]

testRecovery :: IO Property
testRecovery = do
  missingBody <- parse Private "fn run()"
  missingClose <- parse Private "fn run(value: Int {}"
  upperName <- parse Private "fn Run() {}"
  pure $ conjoin
    [ counterexample "missing body" (codes missingBody === ["E1032"])
    , shape missingBody === "private fn run()->_ =invalid"
    , counterexample "missing )" (codes missingClose === ["E1001"])
    , counterexample "uppercase function name" (codes upperName === ["E1012"])
    , remainingKind missingBody === EndOfFile
    ]

testGenerics :: IO Property
testGenerics = do
  typeParameters <- parse Private "fn map[T, U](value: T) -> U {}"
  bounded <- parse Private "fn sort[T: Ord + Clone](values: List[T]) {}"
  whereClause <- parse Private "fn store[T](value: T) where T: Send + Sync {}"
  pure $ conjoin
    [ counterexample "type parameters"
        (shape typeParameters === "private fn map[T,U](value:T)->U {}")
    , counterexample "bounds"
        (shape bounded === "private fn sort[T:Ord+Clone](values:List<T>)->_ {}")
    , counterexample "where clause"
        (shape whereClause === "private fn store[T](value:T)->_ where T:Send+Sync {}")
    , codes whereClause === []
    ]

testHostileParameters :: IO Property
testHostileParameters = do
  let wide = "fn wide(" <> Text.intercalate "," (replicate 520 "a: Int") <> ") {}"
      deep = "fn deep(a: Int = " <> Text.concat (replicate 520 "-") <> "1) {}"
  wideResult <- parse Private wide
  deepResult <- parse Private deep
  pure $ conjoin
    [ counterexample "long parameter lists are ordinary input" (codes wideResult === [])
    , counterexample "every parameter is preserved" (parameterCount wideResult === 520)
    , counterexample "nested defaults report the budget once" (codes deepResult === ["E1099"])
    ]

parameterCount :: Parsed -> Int
parameterCount (Located _ declaration, _, _) = case declaration of
  FunctionDeclaration value -> length (functionParameters value)
  _ -> -1

parse :: Visibility -> Text -> IO Parsed
parse visibility input = do
  source <- newSource (SourceName "function.pudu") input
  let LexResult{lexTokens} = lexSource source
      action = (,) <$> parseFunction visibility <*> peekKind
      ((declaration, remaining), diagnostics) = runParser source action lexTokens
  pure (declaration, remaining, diagnostics)

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
  FunctionDeclaration value ->
    Text.intercalate " "
      [ visibilityText (functionVisibility value)
          <> (if functionAsync value then " async" else Text.empty)
      , "fn"
      , locatedValue (functionName value)
          <> typeParamShape (functionTypeParams value)
          <> "(" <> Text.intercalate "," (map parameterShape (functionParameters value)) <> ")"
          <> "->" <> maybe "_" typeShape (functionReturn value)
          <> whereShape (functionConstraints value)
      , maybe "none" bodyShape (functionBody value)
      ]
  _ -> "other"

typeParamShape :: [Located TypeParam] -> Text
typeParamShape params
  | null params = Text.empty
  | otherwise = "[" <> Text.intercalate "," (map oneParam params) <> "]"
 where
  oneParam (Located _ value) =
    locatedValue (typeParamName value)
      <> boundsShape (typeParamBounds value)

whereShape :: [Located Constraint] -> Text
whereShape constraints
  | null constraints = Text.empty
  | otherwise = " where " <> Text.intercalate "," (map oneConstraint constraints)
 where
  oneConstraint (Located _ value) =
    locatedValue (constraintSubject value) <> boundsShape (constraintBounds value)

boundsShape :: [Located TypeSyntax] -> Text
boundsShape bounds
  | null bounds = Text.empty
  | otherwise = ":" <> Text.intercalate "+" (map typeShape bounds)

visibilityText :: Visibility -> Text
visibilityText visibility = case visibility of
  Private -> "private"
  Exported -> "exported"

parameterShape :: Located Parameter -> Text
parameterShape (Located _ parameter) =
  locatedValue (parameterName parameter)
    <> maybe Text.empty (\value -> ":" <> typeShape value) (parameterType parameter)
    <> maybe Text.empty (\value -> "=" <> expressionShape value) (parameterDefault parameter)

bodyShape :: Located FunctionBody -> Text
bodyShape (Located _ body) = case body of
  BlockBody (Located _ (Block statements result)) ->
    "{" <> Text.intercalate ";" (map statementShape statements)
      <> maybe Text.empty (\value -> "=>" <> expressionShape value) result <> "}"
  ExpressionBody expression -> "=" <> expressionShape expression

statementShape :: Located Statement -> Text
statementShape (Located _ statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name _ value)) ->
    "let " <> locatedValue name <> "=" <> expressionShape value
  DeclarationStatement _ -> "declaration"
  ExpressionStatement expression -> expressionShape expression
  ReturnStatement Nothing -> "return"
  ReturnStatement (Just expression) -> "return " <> expressionShape expression
  InvalidStatement -> "invalid"

typeShape :: Located TypeSyntax -> Text
typeShape (Located _ typeValue) = case typeValue of
  NamedType moduleName arguments ->
    namedShape moduleName
      <> if null arguments then Text.empty
         else "<" <> Text.intercalate "," (map typeShape arguments) <> ">"
  ReferenceType mutable target -> (if mutable then "&mut " else "&") <> typeShape target
  TupleType members -> "(" <> Text.intercalate "," (map typeShape members) <> ")"
  UnitType -> "()"
  InvalidType -> "invalid"

namedShape :: ModuleName -> Text
namedShape = moduleNameText

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
  BlockExpression _ -> "block"
  IfExpression{} -> "if"
  InvalidExpression -> "invalid"
