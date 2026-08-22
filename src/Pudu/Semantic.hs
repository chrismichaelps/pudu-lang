{-| @Semantic.Module — exposes the semantic analysis boundary -}
module Pudu.Semantic
  ( Namespace (..)
  , Reference (..)
  , Resolution (..)
  , Symbol (..)
  , SymbolId (..)
  , SymbolOrigin (..)
  , moduleSymbolNames
  , resolveModule
  ) where

import Data.Text (Text)
import Pudu.Semantic.Resolve (Resolution (..), resolveModule)
import Pudu.Semantic.Symbol
  ( Namespace (..)
  , Reference (..)
  , Symbol (..)
  , SymbolId (..)
  , SymbolOrigin (..)
  )

{-| Names a module declared, whether exported or not. Tooling uses this to show
    what a context holds when nothing in it is public. -}
moduleSymbolNames :: Resolution -> [Text]
moduleSymbolNames resolution =
  [symbolName symbol | symbol <- resolutionSymbols resolution, symbolOrigin symbol == ModuleOrigin]
