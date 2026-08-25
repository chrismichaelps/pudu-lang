{-| @Type.Interface.Module — projects body-free module type interfaces -}
module Pudu.Type.Interface
  ( ImportTypes (..)
  , TypeInterface
  , emptyImportTypes
  , importsFor
  , interfaceDeclarations
  , interfaceDefaults
  , interfaceBindings
  , interfaceImports
  , interfaceModule
  , interfacePrivateDeclarations
  , interfaceSkeleton
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Function (..)
  , Import (..)
  , Impl (..)
  , Module (..)
  , Trait (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeSyntax
  , Parameter (..)
  , Variant (..)
  , Visibility (..)
  )
import Pudu.Type.Value (NominalId, canonicalNominal)

data TypeInterface = TypeInterface
  { interfaceModule :: !ModuleName
  , interfaceImports :: ![Located Import]
  , interfaceDeclarations :: ![Located Declaration]
  , interfacePrivateDeclarations :: ![Located Declaration]
  , interfaceDefaults :: !(Set (NominalId, Text))
  , interfaceBindings :: ![(Text, Located TypeSyntax)]
  }
  deriving stock (Eq, Show)

data ImportTypes = ImportTypes
  { importedInterfaces :: ![TypeInterface]
  , importedNames :: !(Map Text NominalId)
  , importedValues :: !(Map Text Text)
  , importedTraits :: !(Set NominalId)
  }
  deriving stock (Eq, Show)

emptyImportTypes :: ImportTypes
emptyImportTypes = ImportTypes [] Map.empty Map.empty Set.empty

interfaceSkeleton :: Module -> TypeInterface
interfaceSkeleton value =
  TypeInterface
    { interfaceModule = locatedValue (moduleName value)
    , interfaceImports = moduleImports value
    , interfaceDeclarations = mapMaybeDeclaration (moduleDeclarations value)
    , interfacePrivateDeclarations = privateNominalShells (moduleDeclarations value)
    , interfaceDefaults = defaultMembers (locatedValue (moduleName value)) (moduleDeclarations value)
    , interfaceBindings = exportedBindings (moduleDeclarations value)
    }

mapMaybeDeclaration :: [Located Declaration] -> [Located Declaration]
mapMaybeDeclaration = foldr keep []
 where
  keep (Located spanValue declaration) rest = case declaration of
    BindingDeclaration Exported _ _ _ _ -> rest
    FunctionDeclaration value
      | functionVisibility value == Exported && completeSignature value ->
          Located spanValue (FunctionDeclaration value{functionBody = Nothing}) : rest
    TypeDeclaration value
      | typeVisibility value == Exported -> Located spanValue declaration : rest
    TraitDeclaration value
      | traitVisibility value == Exported ->
          Located spanValue
            (TraitDeclaration value{traitMembers = map stripMember (filter (completeSignature . locatedValue) (traitMembers value))}) : rest
    ImplDeclaration value ->
      Located spanValue
        (ImplDeclaration value{implFunctions = map stripMember (filter (completeSignature . locatedValue) (implFunctions value))}) : rest
    _ -> rest
  stripMember (Located spanValue value) = Located spanValue value{functionBody = Nothing}

privateNominalShells :: [Located Declaration] -> [Located Declaration]
privateNominalShells = foldr keep []
 where
  keep located@(Located spanValue declaration) rest = case declaration of
    TypeDeclaration value
      | typeVisibility value == Private -> located : rest
    TraitDeclaration value
      | traitVisibility value == Private ->
          Located spanValue (TraitDeclaration value{traitMembers = []}) : rest
    _ -> rest

completeSignature :: Function -> Bool
completeSignature value =
  functionReturn value /= Nothing
    && all ((/= Nothing) . parameterType . locatedValue) (functionParameters value)

defaultMembers :: ModuleName -> [Located Declaration] -> Set (NominalId, Text)
defaultMembers owner declarations = Set.fromList
  [ (canonicalNominal owner (locatedValue (traitName trait)), locatedValue (functionName member))
  | Located _ (TraitDeclaration trait) <- declarations
  , Located _ member <- traitMembers trait
  , completeSignature member
  , functionBody member /= Nothing
  ]

exportedBindings :: [Located Declaration] -> [(Text, Located TypeSyntax)]
exportedBindings declarations =
  [ (locatedValue name, annotation)
  | Located _ (BindingDeclaration Exported _ name (Just annotation) _) <- declarations
  ]

{-| What a module may see of the program around it.

    Names and values come from what it imported: a name has to be imported to be
    written, and that is the whole point of an import list.

    **Implementations do not.** An implementation is a fact about a type and a
    trait, true everywhere in a program once it exists anywhere in it — which is
    what an orphan rule is for. Scoping them to direct imports made a bounded
    generic unusable across modules: `Std.List.sum` is bounded by `Add`, whose
    implementations live in `Std.Num`, and a caller importing only `Std.List`
    was told `Int does not implement Add` about a program in which it plainly
    does. -}
importsFor :: Map ModuleName TypeInterface -> Module -> ImportTypes
importsFor available consumer =
  (foldMap one (moduleImports consumer)){importedInterfaces = Map.elems available}
 where
  one (Located _ value) =
    case Map.lookup (locatedValue (importModule value)) available of
      Nothing -> emptyImportTypes
      Just found -> importOne value found

instance Semigroup ImportTypes where
  left <> right =
    ImportTypes
      { importedInterfaces = importedInterfaces left <> importedInterfaces right
      , importedNames = importedNames left <> importedNames right
      , importedValues = importedValues left <> importedValues right
      , importedTraits = importedTraits left <> importedTraits right
      }

instance Monoid ImportTypes where
  mempty = emptyImportTypes

importOne :: Import -> TypeInterface -> ImportTypes
importOne value found =
  ImportTypes
    { importedInterfaces = [found]
    , importedNames = Map.fromList (concatMap namesFor exported)
    , importedValues = Map.fromList (concatMap valuesFor exportedValues)
    , importedTraits = Set.fromList [identity | (name, identity, True) <- exported, visible name]
    }
 where
  selected = map locatedValue (importItems value)
  qualifier = maybe (lastSegment (interfaceModule found)) locatedValue (importAlias value)
  visible name = null selected || name `elem` selected
  namesFor (name, identity, _)
    | null selected = [(qualifier <> "." <> name, identity)]
    | name `elem` selected = [(name, identity)]
    | otherwise = []

  valuesFor name
    | null selected = [(qualifier <> "." <> name, canonicalValue name)]
    | name `elem` selected = [(name, canonicalValue name)]
    | otherwise = []
  canonicalValue name = moduleNameText (interfaceModule found) <> "." <> name

  exported = concatMap (exportedIdentity (interfaceModule found)) (interfaceDeclarations found)
  exportedValues = map fst (interfaceBindings found)
    <> concatMap exportedValue (interfaceDeclarations found)

exportedIdentity :: ModuleName -> Located Declaration -> [(Text, NominalId, Bool)]
exportedIdentity owner (Located _ declaration) = case declaration of
  TypeDeclaration value -> [(locatedValue (typeName value), canonicalNominal owner (locatedValue (typeName value)), False)]
  TraitDeclaration value -> [(locatedValue (traitName value), canonicalNominal owner (locatedValue (traitName value)), True)]
  _ -> []

exportedValue :: Located Declaration -> [Text]
exportedValue (Located _ declaration) = case declaration of
  FunctionDeclaration value -> [locatedValue (functionName value)]
  TypeDeclaration value -> case locatedValue (typeDefinition value) of
    SumDefinition variants -> map (locatedValue . variantName . locatedValue) variants
    _ -> []
  _ -> []

lastSegment :: ModuleName -> Text
lastSegment value = case reverse (Text.splitOn "." (moduleNameText value)) of
  first : _ -> first
  [] -> moduleNameText value
