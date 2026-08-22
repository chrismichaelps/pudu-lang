{-| @Semantic.Module — exposes the semantic analysis boundary -}
module Pudu.Semantic
  ( Namespace (..)
  , Reference (..)
  , Resolution (..)
  , Symbol (..)
  , SymbolId (..)
  , SymbolOrigin (..)
  , resolveModule
  ) where

import Pudu.Semantic.Resolve (Resolution (..), resolveModule)
import Pudu.Semantic.Symbol
  ( Namespace (..)
  , Reference (..)
  , Symbol (..)
  , SymbolId (..)
  , SymbolOrigin (..)
  )
