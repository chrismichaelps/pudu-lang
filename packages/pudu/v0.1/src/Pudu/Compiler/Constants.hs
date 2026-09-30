{-| @Program.Compiler.Constants — checked imports available to constant folding -}
module Pudu.Compiler.Constants
  ( foldingInputs
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Compiler (CompileResult (..))
import Pudu.Eval.Frozen (Frozen)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText)
import Pudu.Frontend.Syntax.Tree (Import (..), Module (..))
import Pudu.Source (Span)

{-| Only transitive imports belong in a fold's environment. Unrelated modules
    compiled earlier must not consume its budget or publish their declarations. -}
foldingInputs
  :: Map ModuleName Module
  -> [ModuleName]
  -> ModuleName
  -> Map ModuleName CompileResult
  -> (Map Text (Map Text Frozen), Map Span Text, [(Text, Module)])
foldingInputs modules order owner compiled =
  ( Map.fromList [(moduleNameText name, compileFolded result) | (name, result, _) <- dependencies]
  , Map.unions [compileIntegerKinds result | (_, result, _) <- dependencies]
  , [(moduleNameText name, parsed) | (name, _, parsed) <- dependencies]
  )
 where
  dependencies =
    [(name, result, parsed) | name <- order, Set.member name reachable,
      Just result <- [Map.lookup name compiled], Just parsed <- [compileModule result]]
  reachable = visit (Set.singleton owner) (dependenciesOf owner)
  dependenciesOf name = maybe [] (map (locatedValue . importModule . locatedValue) . moduleImports)
    (Map.lookup name modules)
  visit seen [] = Set.delete owner seen
  visit seen (name : rest)
    | Set.member name seen = visit seen rest
    | otherwise = visit (Set.insert name seen) (dependenciesOf name <> rest)
