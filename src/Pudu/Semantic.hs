{-| @Semantic.Module — exposes the semantic analysis boundary -}
module Pudu.Semantic
  ( Namespace (..)
  , Reference (..)
  , Resolution (..)
  , Symbol (..)
  , SymbolId (..)
  , SymbolOrigin (..)
  , boundSymbolNames
  , moduleSymbolNames
  , resolveModule
  , resolveModuleWith
  , ExportIndex
  , emptyExportIndex
  , exportIndex
  ) where

import Data.Text (Text)
import Pudu.Semantic.Interface (ExportIndex, emptyExportIndex, exportIndex)
import Pudu.Semantic.Resolve (Resolution (..), resolveModule, resolveModuleWith)
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
moduleSymbolNames resolution = namesWithOrigin resolution [ModuleOrigin]

{-| Every name a reader could refer to from the top of a session: module
    declarations, the variants they introduce, and local bindings. -}
boundSymbolNames :: Resolution -> [Text]
boundSymbolNames resolution =
  namesWithOrigin resolution [ModuleOrigin, LocalOrigin, VariantOrigin]

namesWithOrigin :: Resolution -> [SymbolOrigin] -> [Text]
namesWithOrigin resolution origins =
  [ symbolName symbol
  | symbol <- resolutionSymbols resolution
  , symbolOrigin symbol `elem` origins
  ]
