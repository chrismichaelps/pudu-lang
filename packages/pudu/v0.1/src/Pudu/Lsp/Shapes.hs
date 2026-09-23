{-| @Program.Lsp.Shapes — the declared shape of the program's nominal types -}
module Pudu.Lsp.Shapes
  ( RecordShape (..)
  , SumShape (..)
  , VariantShape (..)
  , programRecords
  , programSums
  , recordShapes
  , renderTypeSyntax
  , sumShapes
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileContext (..), CompileResult (..))
import Pudu.Compiler.Program (ProgramResult (..), rootCompileResult)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameSegments, moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , FieldDeclaration (..)
  , Module (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeParam (..)
  , TypeSyntax (..)
  , Variant (..)
  , VariantPayload (..)
  )
import Pudu.Type (Type, renderType)
import Pudu.Type.Interface (interfaceDeclarations)
import Pudu.Type.Interface.Graph (graphInterfaces)
import Pudu.Type.Value (capabilityName)

data VariantShape
  = UnitVariant
  | TupleVariant ![Located TypeSyntax]
  | RecordVariant ![(Text, Located TypeSyntax)]
  deriving stock (Eq, Show)

{-| A sum type as a pattern sees it: its owner, parameters, and payloads. -}
data SumShape = SumShape
  { sumModule :: !ModuleName
  , sumTypeParams :: ![Text]
  , sumVariants :: ![(Text, VariantShape)]
  }
  deriving stock (Eq, Show)

{-| A record type as a member access sees it: its owner, parameters, and
    fields in declaration order, each with whether it is `mut`. -}
data RecordShape = RecordShape
  { recordModule :: !ModuleName
  , recordTypeParams :: ![Text]
  , recordFields :: ![(Text, Bool, Located TypeSyntax)]
  }
  deriving stock (Eq, Show)

{-| The sums a module's declarations define, by the name the type is declared
    under. -}
sumShapes :: ModuleName -> [Located Declaration] -> [(Text, SumShape)]
sumShapes owner declarations =
  [ (name, SumShape owner parameters (map variantShape variants))
  | (name, parameters, SumDefinition variants) <- typeDefinitions declarations
  ]
 where
  variantShape (Located _ variant) =
    ( locatedValue (variantName variant)
    , case variantPayload variant of
        UnitPayload -> UnitVariant
        TuplePayload members -> TupleVariant members
        RecordPayload fields ->
          RecordVariant [(locatedValue (fieldName field), fieldType field) | Located _ field <- fields]
    )

{-| The records a module's declarations define, by the name the type is
    declared under. -}
recordShapes :: ModuleName -> [Located Declaration] -> [(Text, RecordShape)]
recordShapes owner declarations =
  [ ( name
    , RecordShape owner parameters
        [(locatedValue (fieldName field), fieldMutable field, fieldType field) | Located _ field <- fields]
    )
  | (name, parameters, RecordDefinition fields) <- typeDefinitions declarations
  ]

typeDefinitions :: [Located Declaration] -> [(Text, [Text], TypeDefinition)]
typeDefinitions declarations =
  [ ( locatedValue (typeName value)
    , map (locatedValue . typeParamName . locatedValue) (typeTypeParams value)
    , locatedValue (typeDefinition value)
    )
  | Located _ (TypeDeclaration value) <- declarations
  ]

{-| Every sum type the program can see, by canonical name: the document's own,
    and every sum an interface in its program exports. -}
programSums :: ProgramResult -> Map Text SumShape
programSums = programShapes sumShapes

{-| Every record type the program can see, by canonical name, as `programSums`
    finds sums. The key is the declaring module and the name, which is what a
    checked type's nominal identity names, so two modules' `Point` never
    exchange fields. -}
programRecords :: ProgramResult -> Map Text RecordShape
programRecords = programShapes recordShapes

programShapes :: (ModuleName -> [Located Declaration] -> [(Text, shape)]) -> ProgramResult -> Map Text shape
programShapes shapes program =
  Map.fromList
    ( [ (moduleNameText owner <> "." <> name, shape)
      | (owner, interface) <- Map.toList (graphInterfaces (contextTypes (programContext program)))
      , (name, shape) <- shapes owner (interfaceDeclarations interface)
      ]
        <> [ (moduleNameText owner <> "." <> name, shape)
           | Just parsed <- [rootCompileResult program >>= compileSyntax]
           , let owner = locatedValue (moduleName parsed)
           , (name, shape) <- shapes owner (moduleDeclarations parsed)
           ]
    )

{-| A written type as a reader would write it, with the declaration's
    parameters replaced by the types a use supplied. -}
renderTypeSyntax :: Map Text Type -> Located TypeSyntax -> Text
renderTypeSyntax substitutions (Located _ syntax) = case syntax of
  NamedType path arguments ->
    case (moduleNameSegments path, arguments) of
      (name NonEmpty.:| [], []) -> maybe (moduleNameText path) renderType (Map.lookup name substitutions)
      _ -> moduleNameText path <> typeArguments arguments
  DynamicType path -> "dynamic " <> moduleNameText path
  ReferenceType mutable target -> (if mutable then "&mut " else "&") <> renderTypeSyntax substitutions target
  TupleType members -> "(" <> Text.intercalate ", " (map (renderTypeSyntax substitutions) members) <> ")"
  FunctionType asynchronous inputs result ->
    (if asynchronous then "async fn(" else "fn(")
      <> Text.intercalate ", " (map (renderTypeSyntax substitutions) inputs)
      <> ") -> " <> renderTypeSyntax substitutions result
  UnsafeType capabilities target ->
    "unsafe(" <> Text.intercalate ", " (map (capabilityName . locatedValue) capabilities)
      <> ") " <> renderTypeSyntax substitutions target
  UnitType -> "()"
  InvalidType -> "?"
 where
  typeArguments [] = ""
  typeArguments arguments = "[" <> Text.intercalate ", " (map (renderTypeSyntax substitutions) arguments) <> "]"
