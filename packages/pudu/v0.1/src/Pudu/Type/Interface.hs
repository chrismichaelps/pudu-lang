{-| @Type.Interface.Module — projects body-free module type interfaces -}
module Pudu.Type.Interface
  ( TypeInterface
  , interfaceDeclarations
  , interfaceDefaults
  , interfaceBindings
  , interfaceExportedIdentities
  , interfaceExportedValues
  , interfaceImports
  , interfaceIdentities
  , interfaceModule
  , interfacePrivateDeclarations
  , interfaceSkeleton
  ) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Foreign (..)
  , ForeignFunction (..)
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
  , interfaceIdentities :: ![(Text, NominalId)]
  , interfaceExportedIdentities :: ![(Text, NominalId, Bool)]
  , interfaceExportedValues :: ![Text]
  }
  deriving stock (Eq, Show)

interfaceSkeleton :: Module -> TypeInterface
interfaceSkeleton value =
  TypeInterface
    { interfaceModule = owner
    , interfaceImports = moduleImports value
    , interfaceDeclarations = declarations
    , interfacePrivateDeclarations = privateNominalShells (moduleDeclarations value)
    , interfaceDefaults = defaultMembers (locatedValue (moduleName value)) (moduleDeclarations value)
    , interfaceBindings = bindings
    , interfaceIdentities = [(name, identity) | (name, identity, _) <- identities]
    , interfaceExportedIdentities = identities
    , interfaceExportedValues = map fst bindings <> concatMap exportedValue declarations
    }
 where
  owner = locatedValue (moduleName value)
  declarations = mapMaybeDeclaration (moduleDeclarations value)
  bindings = exportedBindings (moduleDeclarations value)
  identities = concatMap (exportedIdentity owner) declarations

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
    ForeignDeclaration value
      | foreignVisibility value == Exported -> Located spanValue declaration : rest
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
    ForeignDeclaration value
      | foreignVisibility value == Private ->
          Located spanValue (ForeignDeclaration value{foreignFunctions = []}) : rest
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

exportedIdentity :: ModuleName -> Located Declaration -> [(Text, NominalId, Bool)]
exportedIdentity owner (Located _ declaration) = case declaration of
  TypeDeclaration value -> [(locatedValue (typeName value), canonicalNominal owner (locatedValue (typeName value)), False)]
  TraitDeclaration value -> [(locatedValue (traitName value), canonicalNominal owner (locatedValue (traitName value)), True)]
  ForeignDeclaration value ->
    [ (locatedValue name, canonicalNominal owner (locatedValue name), False)
    | name <- foreignTypes value
    ]
  _ -> []

exportedValue :: Located Declaration -> [Text]
exportedValue (Located _ declaration) = case declaration of
  FunctionDeclaration value -> [locatedValue (functionName value)]
  ForeignDeclaration value ->
    map (locatedValue . foreignName . locatedValue) (foreignFunctions value)
  TypeDeclaration value -> case locatedValue (typeDefinition value) of
    SumDefinition variants -> map (locatedValue . variantName . locatedValue) variants
    _ -> []
  _ -> []

