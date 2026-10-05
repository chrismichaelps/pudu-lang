{-| @Compiler.ComptimeDependencies — source inputs reachable from expansion and folding. -}
module Pudu.Compiler.ComptimeDependencies (compiletimeDependencies) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Syntax.Tree (Declaration (..), Import (..), Module (..), TypeDeclarationValue (..))

compiletimeDependencies :: Map ModuleName Module -> Set ModuleName
compiletimeDependencies modules = visit Set.empty seeds
 where
  seeds = Map.keysSet (Map.filter (any needsSource . moduleDeclarations) modules)
  visit known pending = case Set.minView pending of
    Nothing -> known
    Just (owner, rest) | Set.member owner known -> visit known rest
    Just (owner, rest) -> case Map.lookup owner modules of
      Nothing -> visit known rest
      Just unit ->
        let next = Set.fromList [locatedValue (importModule value)
              | Located _ value <- moduleImports unit]
         in visit (Set.insert owner known) (Set.union rest (Set.difference next known))
  needsSource (Located _ declaration) = case declaration of
    BindingDeclaration {} -> True
    DeriveDeclaration _ -> True
    DeriveImplDeclaration _ -> True
    TypeDeclaration value -> not (null (typeDerives value))
    _ -> False
