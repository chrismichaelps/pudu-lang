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
  , writableReferences
  , ExportIndex
  , emptyExportIndex
  , exportIndex
  ) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Source (spanEnd, spanStart, unOffset)
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

{-| The spans of every use of a name that was declared with `var`.

    Whether an assignment may replace a binding is a fact about the binding,
    and the resolver is what knows which binding a use reaches through every
    shadowing scope. The checker is handed these spans, keyed as it keys every
    expression, rather than scoping names a second time to rediscover it. -}
writableReferences :: Resolution -> Set (Int, Int)
writableReferences resolution =
  Set.fromList
    [ (unOffset (spanStart (referenceSpan reference)), unOffset (spanEnd (referenceSpan reference)))
    | reference <- resolutionReferences resolution
    , Set.member (referenceSymbol reference) mutable
    ]
 where
  mutable =
    Set.fromList [symbolId symbol | symbol <- resolutionSymbols resolution, symbolMutable symbol]

namesWithOrigin :: Resolution -> [SymbolOrigin] -> [Text]
namesWithOrigin resolution origins =
  [ symbolName symbol
  | symbol <- resolutionSymbols resolution
  , symbolOrigin symbol `elem` origins
  ]
