{-| @Semantic.Interface.Module — projects module exports for import resolution -}
module Pudu.Semantic.Interface
  ( ExportIndex
  , ExportedName (..)
  , ImportBinding (..)
  , ModuleExports
  , emptyExportIndex
  , exportIndex
  , importBindings
  , moduleExports
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (Error)
  , diagnostic
  , mkDiagnosticCode
  , withHelp
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Function (..)
  , Import (..)
  , Module (..)
  , Trait (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , Variant (..)
  , Visibility (..)
  )
import Pudu.Semantic.Symbol (Namespace (..))
import Pudu.Source (Span)

data ExportedName = ExportedName
  { exportedModule :: !ModuleName
  , exportedNamespace :: !Namespace
  , exportedName :: !Text
  , exportedSpan :: !Span
  }
  deriving stock (Eq, Show)

data ImportBinding = ImportBinding
  { bindingNamespace :: !Namespace
  , bindingName :: !Text
  , bindingSpan :: !Span
  }
  deriving stock (Eq, Show)

newtype ModuleExports = ModuleExports (Map (Namespace, Text) ExportedName)
  deriving stock (Eq, Show)

newtype ExportIndex = ExportIndex (Map ModuleName ModuleExports)
  deriving stock (Eq, Show)

emptyExportIndex :: ExportIndex
emptyExportIndex = ExportIndex Map.empty

exportIndex :: Map ModuleName Module -> ExportIndex
exportIndex modules = ExportIndex (Map.map moduleExports modules)

moduleExports :: Module -> ModuleExports
moduleExports moduleValue =
  ModuleExports
    (Map.fromList (concatMap (declarationExports owner) (moduleDeclarations moduleValue)))
 where
  owner = locatedValue (moduleName moduleValue)

declarationExports :: ModuleName -> Located Declaration -> [((Namespace, Text), ExportedName)]
declarationExports owner (Located _ declaration) = case declaration of
  BindingDeclaration Exported _ name _ _ -> one ValueSpace name
  FunctionDeclaration value
    | functionVisibility value == Exported -> one ValueSpace (functionName value)
  TypeDeclaration value
    | typeVisibility value == Exported ->
        one TypeSpace (typeName value) <> variantExports owner (typeDefinition value)
  TraitDeclaration value
    | traitVisibility value == Exported -> one TypeSpace (traitName value)
  _ -> []
 where
  one namespace name =
    let value = ExportedName owner namespace (locatedValue name) (locatedSpan name)
     in [((namespace, locatedValue name), value)]

variantExports
  :: ModuleName -> Located TypeDefinition -> [((Namespace, Text), ExportedName)]
variantExports owner (Located _ definition) = case definition of
  SumDefinition variants -> map exportVariant variants
  _ -> []
 where
  exportVariant (Located _ variant) =
    let name = variantName variant
        value = ExportedName owner ValueSpace (locatedValue name) (locatedSpan name)
     in ((ValueSpace, locatedValue name), value)

importBindings :: ExportIndex -> Located Import -> ([ImportBinding], [Diagnostic])
importBindings (ExportIndex modules) (Located importSpan value) =
  case Map.lookup importedModule modules of
    Nothing -> (opaqueBindings value qualifier importSpan, [])
    Just exports -> case importItems value of
      [] -> (qualifierBindings qualifier importSpan, [])
      items -> foldMap (selectedBindings importedModule exports) items
 where
  importedModule = locatedValue (importModule value)
  qualifier = maybe (lastModuleSegment importedModule) locatedValue (importAlias value)

selectedBindings
  :: ModuleName -> ModuleExports -> Located Text -> ([ImportBinding], [Diagnostic])
selectedBindings owner (ModuleExports exports) item =
  case matches of
    [] -> ([], maybe [] pure (notExported owner item))
    _ -> (map toBinding matches, [])
 where
  matches =
    [ found
    | namespace <- [ValueSpace, TypeSpace]
    , Just found <- [Map.lookup (namespace, locatedValue item) exports]
    ]
  toBinding found =
    ImportBinding (exportedNamespace found) (locatedValue item) (locatedSpan item)

qualifierBindings :: Text -> Span -> [ImportBinding]
qualifierBindings name spanValue =
  [ ImportBinding ValueSpace name spanValue
  , ImportBinding TypeSpace name spanValue
  ]

opaqueBindings :: Import -> Text -> Span -> [ImportBinding]
opaqueBindings value qualifier spanValue = case importItems value of
  [] -> qualifierBindings qualifier spanValue
  items ->
    [ ImportBinding namespace (locatedValue item) (locatedSpan item)
    | item <- items
    , namespace <- [ValueSpace, TypeSpace]
    ]

notExported :: ModuleName -> Located Text -> Maybe Diagnostic
notExported owner item = do
  code <- mkDiagnosticCode "E2013"
  value <- diagnostic code Error (locatedSpan item)
    (locatedValue item <> " is not exported by " <> moduleNameText owner)
  pure (withHelp "export the declaration, or remove it from the import selection" value)

lastModuleSegment :: ModuleName -> Text
lastModuleSegment name =
  case reverse (Text.splitOn "." (moduleNameText name)) of
    segment : _ -> segment
    [] -> moduleNameText name
