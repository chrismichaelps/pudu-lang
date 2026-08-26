module Pudu.Frontend.ParserTypeDeclarationSpec (parserTypeDeclarationProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Declaration.Trait (parseImpl, parseTrait)
import Pudu.Frontend.Parser.Declaration.Type (parseTypeDeclaration)
import Pudu.Frontend.Parser.State (Parser, peekKind, runParser)
import Pudu.Frontend.Syntax
  ( Constraint (..)
  , Declaration (..)
  , FieldDeclaration (..)
  , Function (..)
  , Impl (..)
  , Located (..)
  , Trait (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeParam (..)
  , TypeSyntax (..)
  , Variant (..)
  , VariantPayload (..)
  , Visibility (..)
  , moduleNameText
  )
import Pudu.Frontend.Token (TokenKind (..))
import Pudu.Source (SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

type Parsed = (Located Declaration, TokenKind, [Diagnostic])

parserTypeDeclarationProperties :: [(String, IO Property)]
parserTypeDeclarationProperties =
  [ ("record declarations preserve field mutability and types", testRecords)
  , ("sum declarations preserve variants and payloads", testSums)
  , ("alias declarations preserve one type reference", testAliases)
  , ("generic type declarations carry parameters and bounds", testGenerics)
  , ("traits declare required and default members", testTraits)
  , ("implementations bind a trait to a target type", testImpls)
  , ("declaration recovery emits exact diagnostics", testRecovery)
  ]

testRecords :: IO Property
testRecords = do
  simple <- parseType "type User = { id: Int64, name: Str }"
  mutable <- parseType "type Counter = { mut total: Int, label: Str }"
  trailing <- parseType "type One = { only: Bool, }"
  pure $ conjoin
    [ shape simple === "type User={id:Int64,name:Str}"
    , counterexample "mut is preserved" (shape mutable === "type Counter={mut total:Int,label:Str}")
    , shape trailing === "type One={only:Bool}"
    , codes mutable === []
    ]

testSums :: IO Property
testSums = do
  leading <- parseType "type Result = | Ok(Int) | Err(Str)"
  bare <- parseType "type Choice = Yes | No"
  recordPayload <- parseType "type Shape = Circle{radius: Float} | Square{side: Float}"
  pure $ conjoin
    [ shape leading === "type Result=Ok(Int)|Err(Str)"
    , counterexample "a pipe after the first variant still forms a sum"
        (shape bare === "type Choice=Yes|No")
    , shape recordPayload === "type Shape=Circle{radius:Float}|Square{side:Float}"
    , codes leading === []
    ]

testAliases :: IO Property
testAliases = do
  named <- parseType "type Meters = Int64"
  generic <- parseType "type Names = List[Str]"
  functionType <- parseType "type Handler = fn(Request) -> Response"
  asyncType <- parseType "type Fetcher = async fn(Str) -> Response"
  pure $ conjoin
    [ shape named === "type Meters=Int64"
    , shape generic === "type Names=List<Str>"
    , counterexample "function types parse" (shape functionType === "type Handler=fn(Request)->Response")
    , shape asyncType === "type Fetcher=async fn(Str)->Response"
    , codes functionType === []
    ]

testGenerics :: IO Property
testGenerics = do
  parameters <- parseType "type Pair[A, B] = { left: A, right: B }"
  bounded <- parseType "type Sorted[T: Ord] = { items: List[T] }"
  pure $ conjoin
    [ shape parameters === "type Pair[A,B]={left:A,right:B}"
    , shape bounded === "type Sorted[T:Ord]={items:List<T>}"
    , codes bounded === []
    ]

testTraits :: IO Property
testTraits = do
  required <- parseTraitInput "trait Show {\n  fn show(self: &Self) -> Str\n}"
  mixed <- parseTraitInput "trait Greet {\n  fn name(self: &Self) -> Str\n  fn hello(self: &Self) -> Str = \"hi\"\n}"
  generic <- parseTraitInput "trait Into[T] where T: Send {\n  fn into(self: Self) -> T\n}"
  pure $ conjoin
    [ shape required === "trait Show{fn show:none}"
    , counterexample "default bodies are preserved" (shape mixed === "trait Greet{fn name:none;fn hello:body}")
    , shape generic === "trait Into[T] where T:Send{fn into:none}"
    , codes generic === []
    ]

testImpls :: IO Property
testImpls = do
  simple <- parseImplInput "impl Show for User {\n  fn show(self: &Self) -> Str { self.name }\n}"
  generic <- parseImplInput "impl[T] Show for List[T] where T: Show {\n  fn show(self: &Self) -> Str = \"list\"\n}"
  pure $ conjoin
    [ shape simple === "impl Show for User{fn show:body}"
    , shape generic === "impl[T] Show for List<T> where T:Show{fn show:body}"
    , codes generic === []
    ]

testRecovery :: IO Property
testRecovery = do
  lowercaseName <- parseType "type user = { id: Int }"
  missingEquals <- parseType "type User { id: Int }"
  nonFunctionMember <- parseTraitInput "trait Bad {\n  let value = 1\n}"
  pure $ conjoin
    [ counterexample "type names are uppercase" (codes lowercaseName === ["E1011"])
    , counterexample "missing =" (codes missingEquals === ["E1001"])
    , counterexample "trait members are functions" (codes nonFunctionMember === ["E1052"])
    ]

parseType :: Text -> IO Parsed
parseType = parseWith (parseTypeDeclaration Private)

parseTraitInput :: Text -> IO Parsed
parseTraitInput = parseWith (parseTrait Private)

parseImplInput :: Text -> IO Parsed
parseImplInput = parseWith parseImpl

parseWith :: Parser (Located Declaration) -> Text -> IO Parsed
parseWith action input = do
  source <- newSource (SourceName "declaration.pudu") input
  let LexResult{lexTokens} = lexSource source
      combined = (,) <$> action <*> peekKind
      ((declaration, remaining), diagnostics) = runParser source combined lexTokens
  pure (declaration, remaining, diagnostics)

codes :: Parsed -> [Text]
codes (_, _, diagnostics) = map (diagnosticCodeText . diagnosticCode) diagnostics

shape :: Parsed -> Text
shape (Located _ declaration, _, _) = case declaration of
  TypeDeclaration value ->
    "type " <> locatedValue (typeName value)
      <> paramShape (typeTypeParams value)
      <> "=" <> definitionShape (typeDefinition value)
  TraitDeclaration value ->
    "trait " <> locatedValue (traitName value)
      <> paramShape (traitTypeParams value)
      <> whereShape (traitConstraints value)
      <> "{" <> Text.intercalate ";" (map memberShape (traitMembers value)) <> "}"
  ImplDeclaration value ->
    "impl" <> paramShape (implTypeParams value)
      <> " " <> typeShape (implTrait value)
      <> " for " <> typeShape (implTarget value)
      <> whereShape (implConstraints value)
      <> "{" <> Text.intercalate ";" (map memberShape (implFunctions value)) <> "}"
  _ -> "other"

memberShape :: Located Function -> Text
memberShape (Located _ value) =
  "fn " <> locatedValue (functionName value)
    <> maybe ":none" (const ":body") (functionBody value)

paramShape :: [Located TypeParam] -> Text
paramShape params
  | null params = Text.empty
  | otherwise = "[" <> Text.intercalate "," (map one params) <> "]"
 where
  one (Located _ value) = locatedValue (typeParamName value) <> boundsShape (typeParamBounds value)

whereShape :: [Located Constraint] -> Text
whereShape constraints
  | null constraints = Text.empty
  | otherwise = " where " <> Text.intercalate "," (map one constraints)
 where
  one (Located _ value) = locatedValue (constraintSubject value) <> boundsShape (constraintBounds value)

boundsShape :: [Located TypeSyntax] -> Text
boundsShape bounds
  | null bounds = Text.empty
  | otherwise = ":" <> Text.intercalate "+" (map typeShape bounds)

definitionShape :: Located TypeDefinition -> Text
definitionShape (Located _ definition) = case definition of
  RecordDefinition fields -> "{" <> Text.intercalate "," (map fieldShape fields) <> "}"
  SumDefinition variants -> Text.intercalate "|" (map variantShape variants)
  AliasDefinition aliased -> typeShape aliased
  InvalidDefinition -> "invalid"

fieldShape :: Located FieldDeclaration -> Text
fieldShape (Located _ field) =
  (if fieldMutable field then "mut " else Text.empty)
    <> locatedValue (fieldName field) <> ":" <> typeShape (fieldType field)

variantShape :: Located Variant -> Text
variantShape (Located _ variant) =
  locatedValue (variantName variant) <> case variantPayload variant of
    UnitPayload -> Text.empty
    TuplePayload members -> "(" <> Text.intercalate "," (map typeShape members) <> ")"
    RecordPayload fields -> "{" <> Text.intercalate "," (map fieldShape fields) <> "}"

typeShape :: Located TypeSyntax -> Text
typeShape (Located _ value) = case value of
  DynamicType path -> "dynamic " <> moduleNameText path
  NamedType path arguments ->
    moduleNameText path
      <> if null arguments then Text.empty
         else "<" <> Text.intercalate "," (map typeShape arguments) <> ">"
  ReferenceType mutable target -> (if mutable then "&mut " else "&") <> typeShape target
  TupleType members -> "(" <> Text.intercalate "," (map typeShape members) <> ")"
  FunctionType asynchronous inputs result ->
    (if asynchronous then "async fn(" else "fn(")
      <> Text.intercalate "," (map typeShape inputs) <> ")->" <> typeShape result
  UnitType -> "()"
  InvalidType -> "invalid"
