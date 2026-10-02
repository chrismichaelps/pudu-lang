{-| @Semantic.Resolve.Reflection — classifies compile-time imports once -}
module Pudu.Semantic.Resolve.Reflection (reflectionImports) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText, moduleQualifier)
import Pudu.Frontend.Syntax.Tree (Import (..))
import Pudu.Semantic.Symbol (Namespace (..))

{-| Selected items are reflection bindings too. Restriction checks later use
    the resolved symbol's namespace and origin, so local shadowing is lexical
    and a value cannot hide the independent type namespace. -}
reflectionImports :: [Located Import] -> Set (Namespace, Text)
reflectionImports imports = Set.fromList
  [ (namespace, name)
  | Located _ value <- imports
  , moduleNameText (locatedValue (importModule value)) == "Std.Meta"
  , name <- importedNames value
  , namespace <- [ValueSpace, TypeSpace]
  ]
 where
  importedNames value = case importItems value of
    [] -> [maybe (moduleQualifier (locatedValue (importModule value))) locatedValue
            (importAlias value)]
    items -> map locatedValue items
