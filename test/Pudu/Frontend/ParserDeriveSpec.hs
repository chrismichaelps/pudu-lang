{-| @Test.Frontend.ParserDerive — derive surface syntax parses and recovers -}
module Pudu.Frontend.ParserDeriveSpec (parserDeriveProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser (ParseResult (..), parseModule)
import Pudu.Frontend.Syntax
  ( Attribute (..)
  , Block (..)
  , ComptimeFor (..)
  , Constraint (..)
  , Declaration (..)
  , Derive (..)
  , DeriveRequest (..)
  , DeriveShape (..)
  , Expression (..)
  , FieldDeclaration (..)
  , Function (..)
  , FunctionBody (..)
  , Literal (..)
  , Located (..)
  , Module (..)
  , Statement (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeSyntax (..)
  , Variant (..)
  , Visibility (..)
  , locatedValue
  , moduleNameText
  )
import Pudu.Source (SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

type Parsed = (Maybe Module, [Diagnostic])

parserDeriveProperties :: [(String, IO Property)]
parserDeriveProperties =
  [ ("attributes keep names and literal arguments", testAttributes)
  , ("a bad attribute argument is E1067", testBadArgument)
  , ("derives clauses keep entries in order", testDerives)
  , ("a repeated derives entry is E1066", testDuplicateDerives)
  , ("a missing derives entry is E1065", testMissingDerives)
  , ("derive definitions keep trait, parameter, shape, and members", testDeriveDefinition)
  , ("a bad derive shape is E1068", testBadShape)
  , ("derive impl requests keep trait and target", testDeriveRequest)
  , ("misplaced attributes are E1064", testMisplacedAttributes)
  , ("comptime loops keep element, type, source, bounds, and body", testComptimeFor)
  , ("a comptime loop without bounds parses", testComptimeForPlain)
  , ("derive stays an ordinary identifier elsewhere", testDeriveIdentifier)
  , ("variant attributes are kept", testVariantAttributes)
  , ("export before attributes is E1064", testExportOrder)
  , ("attributes on other declarations are E1064", testMisplacedKinds)
  , ("derives works on aliases with trailing commas", testDerivesAlias)
  , ("a lowercase derives ends the sum", testDerivesEndsSum)
  , ("every literal kind fits in arguments", testAllLiterals)
  , ("empty attribute args parse", testEmptyArgs)
  , ("lone comptime keeps its diagnostic", testLoneComptime)
  , ("exported derives keep visibility", testExportedDerive)
  ]

parseModuleText :: Text -> IO Parsed
parseModuleText input = do
  source <- newSource (SourceName "derive.pudu") input
  let LexResult{lexTokens} = lexSource source
      ParseResult{parseModuleValue, parseDiagnostics} = parseModule source lexTokens
  pure (parseModuleValue, parseDiagnostics)

declarationsOf :: Parsed -> [Declaration]
declarationsOf (Nothing, _) = []
declarationsOf (Just moduleValue, _) = map locatedValue (moduleDeclarations moduleValue)

codes :: Parsed -> [Text]
codes (_, diagnostics) = map (diagnosticCodeText . diagnosticCode) diagnostics

attributeShape :: Located Attribute -> Text
attributeShape (Located _ attribute) =
  "@" <> locatedValue (attributeName attribute)
    <> if null (attributeArguments attribute)
      then Text.empty
      else "(" <> Text.intercalate "," (map literalShape (attributeArguments attribute)) <> ")"

literalShape :: Located Literal -> Text
literalShape (Located _ literal) = case literal of
  IntegerValue text -> text
  FloatValue text -> text
  DecimalValue text -> text
  StringValue text -> "\"" <> text <> "\""
  CharValue character -> "'" <> Text.singleton character <> "'"
  BoolValue True -> "true"
  BoolValue False -> "false"
  NullValue -> "null"
  ResolvedInteger _ number -> Text.pack (show number)

typeShape :: Located TypeSyntax -> Text
typeShape (Located _ syntax) = case syntax of
  NamedType path arguments ->
    moduleNameText path <> if null arguments then Text.empty else "[arguments]"
  _ -> "other"

derivesShape :: [Located TypeSyntax] -> Text
derivesShape entries = Text.intercalate "," (map typeShape entries)

testAttributes :: IO Property
testAttributes = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "@json(\"order_id\") type Order = { @skip cache: Option[Str], lines: Array[Line] }"
    ])
  pure $ case declarationsOf parsed of
    [TypeDeclaration value] ->
      let fields = case locatedValue (typeDefinition value) of
            RecordDefinition held -> held
            _ -> []
       in conjoin
        [ counterexample "type attributes" (map attributeShape (typeAttributes value) === ["@json(\"order_id\")"])
        , counterexample "field attributes" (map (map attributeShape . fieldAttributes . locatedValue) fields === [["@skip"], []])
        , counterexample "derives" (derivesShape (typeDerives value) === "")
        , counterexample "no diagnostics" (codes parsed === [])
        ]
    _ -> counterexample "one type declaration" False

testBadArgument :: IO Property
testBadArgument = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "type Order = { @json(id) id: Int }"
    ])
  pure $ conjoin
    [ counterexample "E1067" (codes parsed === ["E1067"])
    ]

testDerives :: IO Property
testDerives = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "type Order = { id: Int } derives Eq, Hash"
    ])
  pure $ case declarationsOf parsed of
    [TypeDeclaration value] -> conjoin
      [ counterexample "entries in order" (derivesShape (typeDerives value) === "Eq,Hash")
      , counterexample "no diagnostics" (codes parsed === [])
      ]
    _ -> counterexample "one type declaration" False

testDuplicateDerives :: IO Property
testDuplicateDerives = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "type Order = { id: Int } derives Eq, Eq"
    ])
  pure $ case declarationsOf parsed of
    [TypeDeclaration value] -> conjoin
      [ counterexample "E1066" (codes parsed === ["E1066"])
      , counterexample "both entries kept" (derivesShape (typeDerives value) === "Eq,Eq")
      ]
    _ -> counterexample "one type declaration" False

testMissingDerives :: IO Property
testMissingDerives = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "type Order = { id: Int } derives"
    ])
  pure $ counterexample "E1065" (codes parsed === ["E1065"])

testDeriveDefinition :: IO Property
testDeriveDefinition = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "derive Encode for T: Record {"
    , "  fn encode(self: &T) -> Str { \"\" }"
    , "}"
    ])
  pure $ case declarationsOf parsed of
    [DeriveDeclaration value] -> conjoin
      [ counterexample "trait" (typeShape (deriveTrait value) === "Encode")
      , counterexample "parameter" (locatedValue (deriveParameter value) === "T")
      , counterexample "shape" (locatedValue (deriveShape value) === RecordShape)
      , counterexample "member" (map (locatedValue . functionName . locatedValue) (deriveFunctions value) === ["encode"])
      , counterexample "no diagnostics" (codes parsed === [])
      ]
    _ -> counterexample "one derive declaration" False

testBadShape :: IO Property
testBadShape = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "derive Encode for T: Table {"
    , "}"
    ])
  pure $ counterexample "E1068" (codes parsed === ["E1068"])

testDeriveRequest :: IO Property
testDeriveRequest = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "derive impl Eq for Line"
    ])
  pure $ case declarationsOf parsed of
    [DeriveImplDeclaration value] -> conjoin
      [ counterexample "trait" (typeShape (deriveRequestTrait value) === "Eq")
      , counterexample "target" (typeShape (deriveRequestTarget value) === "Line")
      , counterexample "no diagnostics" (codes parsed === [])
      ]
    _ -> counterexample "one derive request" False

testMisplacedAttributes :: IO Property
testMisplacedAttributes = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "@skip fn run() -> Int { 1 }"
    ])
  pure $ counterexample "E1064" (codes parsed === ["E1064"])

testComptimeFor :: IO Property
testComptimeFor = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "fn run(fields: Array[Str]) -> Int {"
    , "  var total = 0"
    , "  comptime for field: Meta.Field[T, F] in Meta.fields[T]() where F: Encode {"
    , "    total = total + 1"
    , "  }"
    , "  total"
    , "}"
    ])
  pure $ case comptimeLoops parsed of
    [loop] -> conjoin
      [ counterexample "element" (locatedValue (comptimeForElement loop) === "field")
      , counterexample "one bound" (length (comptimeForConstraints loop) === 1)
      , counterexample "bound subject" (boundSubjects loop === ["F"])
      , counterexample "no diagnostics" (codes parsed === [])
      ]
    _ -> counterexample "one comptime loop" False

boundSubjects :: ComptimeFor -> [Text]
boundSubjects loop =
  [locatedValue (constraintSubject constraint) | Located _ constraint <- comptimeForConstraints loop]

comptimeLoops :: Parsed -> [ComptimeFor]
comptimeLoops parsed = concatMap fromDeclaration (declarationsOf parsed)
 where
  fromDeclaration declaration = case declaration of
    FunctionDeclaration function -> case functionBody function of
      Just (Located _ (BlockBody block)) -> fromBlock block
      _ -> []
    _ -> []
  fromBlock (Located _ block) =
    concatMap fromStatement (blockStatements block)
      <> maybe [] fromExpression (blockResult block)
  fromStatement statement = case locatedValue statement of
    ExpressionStatement expression -> fromExpression expression
    _ -> []
  fromExpression expression = case locatedValue expression of
    ComptimeForExpression loop -> [loop]
    _ -> []

testComptimeForPlain :: IO Property
testComptimeForPlain = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "fn run(items: Array[Int]) -> Int {"
    , "  var total = 0"
    , "  comptime for item: Int in items {"
    , "    total = total + item"
    , "  }"
    , "  total"
    , "}"
    ])
  pure $ case comptimeLoops parsed of
    [loop] -> conjoin
      [ counterexample "element" (locatedValue (comptimeForElement loop) === "item")
      , counterexample "no bounds" (null (comptimeForConstraints loop) === True)
      , counterexample "no diagnostics" (codes parsed === [])
      ]
    _ -> counterexample "one comptime loop" False

testDeriveIdentifier :: IO Property
testDeriveIdentifier = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "fn derive(count: Int) -> Int { count }"
    ])
  pure $ conjoin
    [ counterexample "derive still names a function" (functionNames parsed === ["derive"])
    , counterexample "no diagnostics" (codes parsed === [])
    ]

testVariantAttributes :: IO Property
testVariantAttributes = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "type Shape = @round Circle{radius: Float} | Square{side: Float}"
    ])
  pure $ case declarationsOf parsed of
    [TypeDeclaration value] -> case locatedValue (typeDefinition value) of
      SumDefinition variants -> conjoin
        [ counterexample "variant attributes"
            (map (map attributeShape . variantAttributes . locatedValue) variants === [["@round"], []])
        , counterexample "no diagnostics" (codes parsed === [])
        ]
      _ -> counterexample "a sum definition" False
    _ -> counterexample "one type declaration" False

testExportOrder :: IO Property
testExportOrder = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "export @json(\"id\") type Order = { id: Int }"
    ])
  pure $ case declarationsOf parsed of
    [TypeDeclaration value] -> conjoin
      [ counterexample "E1064" (codes parsed === ["E1064"])
      , counterexample "attributes kept" (map attributeShape (typeAttributes value) === ["@json(\"id\")"])
      ]
    _ -> counterexample "one type declaration" False

testMisplacedKinds :: IO Property
testMisplacedKinds = do
  trait <- parseModuleText (Text.unlines
    [ "module M"
    , "@sealed trait Show { }"
    ])
  impl <- parseModuleText (Text.unlines
    [ "module M"
    , "trait Show { }"
    , "@fast impl Show for Int { }"
    ])
  pure $ conjoin
    [ counterexample "trait attributes E1064" (codes trait === ["E1064"])
    , counterexample "trait kept" (declarationKinds trait === ["trait"])
    , counterexample "impl attributes E1064" (codes impl === ["E1064"])
    , counterexample "impl kept" (declarationKinds impl === ["trait", "impl"])
    ]

declarationKinds :: Parsed -> [Text]
declarationKinds parsed = map kindOf (declarationsOf parsed)
 where
  kindOf declaration = case declaration of
    TypeDeclaration _ -> "type"
    TraitDeclaration _ -> "trait"
    ImplDeclaration _ -> "impl"
    FunctionDeclaration _ -> "fn"
    DeriveDeclaration _ -> "derive"
    DeriveImplDeclaration _ -> "derive impl"
    _ -> "other"

testDerivesAlias :: IO Property
testDerivesAlias = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "type Meters = Int derives Eq,"
    ])
  pure $ case declarationsOf parsed of
    [TypeDeclaration value] -> conjoin
      [ counterexample "entry kept" (derivesShape (typeDerives value) === "Eq")
      , counterexample "no diagnostics" (codes parsed === [])
      ]
    _ -> counterexample "one type declaration" False

testDerivesEndsSum :: IO Property
testDerivesEndsSum = do
  ended <- parseModuleText (Text.unlines
    [ "module M"
    , "type Choice = Yes | No derives"
    ])
  lowered <- parseModuleText (Text.unlines
    [ "module M"
    , "type Choice = Yes | no"
    ])
  pure $ conjoin
    [ counterexample "empty clause after a sum" (codes ended === ["E1065"])
    , counterexample "lowercase variant still E1011" (codes lowered === ["E1011"])
    ]

testAllLiterals :: IO Property
testAllLiterals = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "@all(1, 2.5, 1.5d, \"s\", 'c', true, false, null) type T = { x: Int }"
    ])
  pure $ case declarationsOf parsed of
    [TypeDeclaration value] -> conjoin
      [ counterexample "eight arguments"
          (map (length . attributeArguments . locatedValue) (typeAttributes value) === [8])
      , counterexample "no diagnostics" (codes parsed === [])
      ]
    _ -> counterexample "one type declaration" False

testEmptyArgs :: IO Property
testEmptyArgs = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "@marker() type T = { x: Int }"
    ])
  pure $ case declarationsOf parsed of
    [TypeDeclaration value] -> conjoin
      [ counterexample "bare attribute" (map attributeShape (typeAttributes value) === ["@marker"])
      , counterexample "no diagnostics" (codes parsed === [])
      ]
    _ -> counterexample "one type declaration" False

testLoneComptime :: IO Property
testLoneComptime = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "fn run() -> Int {"
    , "  comptime"
    , "  1"
    , "}"
    ])
  pure $ counterexample "existing diagnostic preserved" ("E1040" `elem` codes parsed)

testExportedDerive :: IO Property
testExportedDerive = do
  parsed <- parseModuleText (Text.unlines
    [ "module M"
    , "export derive Encode for T: Record {"
    , "}"
    ])
  pure $ case declarationsOf parsed of
    [DeriveDeclaration value] -> conjoin
      [ counterexample "exported" (deriveVisibility value === Exported)
      , counterexample "no diagnostics" (codes parsed === [])
      ]
    _ -> counterexample "one derive declaration" False

functionNames :: Parsed -> [Text]
functionNames parsed = case declarationsOf parsed of
  [FunctionDeclaration value] -> [locatedValue (functionName value)]
  _ -> []
