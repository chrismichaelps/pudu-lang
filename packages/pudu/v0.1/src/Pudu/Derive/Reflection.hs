{-| @Derive.Reflection — canonical resolved metadata references for residualization. -}
module Pudu.Derive.Reflection (ReflectionBinding (..), reflectionReferences) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText, moduleQualifier)
import Pudu.Frontend.Syntax.Tree (Import (..), Module (..))
import Pudu.Semantic
  ( Namespace (ValueSpace), Reference (..), Resolution (..), Symbol (..)
  , SymbolOrigin (ImportOrigin, ModuleOrigin) )
import Pudu.Source (Span)

data ReflectionBinding = MetadataModule | MetadataFunction !Text
  deriving stock (Eq, Show)

reflectionReferences :: Module -> Resolution -> Map Span ReflectionBinding
reflectionReferences moduleValue resolved = Map.fromList
  [ (referenceSpan reference, binding)
  | reference <- resolutionReferences resolved
  , Just symbol <- [Map.lookup (referenceSymbol reference) symbols]
  , symbolNamespace symbol == ValueSpace
  , Just binding <- [classify symbol]
  ]
 where
  symbols = Map.fromList [(symbolId symbol, symbol) | symbol <- resolutionSymbols resolved]
  imported = Map.fromList
    [ (name, binding)
    | Located _ value <- moduleImports moduleValue
    , moduleNameText (locatedValue (importModule value)) == "Std.Meta"
    , (name, binding) <- case importItems value of
        [] -> [(maybe (moduleQualifier (locatedValue (importModule value))) locatedValue (importAlias value), MetadataModule)]
        items -> [(locatedValue name, MetadataFunction (locatedValue name)) | name <- items]
    ]
  classify symbol = case symbolOrigin symbol of
    ImportOrigin -> Map.lookup (symbolName symbol) imported
    ModuleOrigin | moduleNameText (locatedValue (moduleName moduleValue)) == "Std.Meta" ->
      Just (MetadataFunction (symbolName symbol))
    _ -> Nothing
