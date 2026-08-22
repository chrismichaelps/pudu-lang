{-| @Semantic.Symbol.Module — identifies every named entity -}
module Pudu.Semantic.Symbol
  ( Namespace (..)
  , Reference (..)
  , Symbol (..)
  , SymbolId (..)
  , SymbolOrigin (..)
  , isShadowWarned
  ) where

import Data.Text (Text)
import Pudu.Frontend.Syntax.Tree (Visibility)
import Pudu.Source (Span)

{-| @Semantic.Symbol.Id — stable identity independent of spelling -}
newtype SymbolId = SymbolId Int
  deriving stock (Eq, Ord, Show)

{-| @Semantic.Symbol.Namespace — separates value and type names -}
data Namespace = ValueSpace | TypeSpace
  deriving stock (Eq, Ord, Show)

{-| @Semantic.Symbol.Origin — records where a binding came from, which the
    shadowing rule distinguishes -}
data SymbolOrigin
  = BuiltinOrigin
  | PreludeOrigin
  | ModuleOrigin
  | ImportOrigin
  | ParameterOrigin
  | LocalOrigin
  | TypeParamOrigin
  | PatternOrigin
  | VariantOrigin
  deriving stock (Eq, Ord, Show)

{-| @Semantic.Symbol.Value — one resolved declaration -}
data Symbol = Symbol
  { symbolId :: !SymbolId
  , symbolName :: !Text
  , symbolNamespace :: !Namespace
  , symbolOrigin :: !SymbolOrigin
  , symbolMutable :: !Bool
  , symbolVisibility :: !Visibility
  , symbolSpan :: !(Maybe Span)
  }
  deriving stock (Eq, Show)

{-| @Semantic.Symbol.Reference — one resolved use site -}
data Reference = Reference
  { referenceSpan :: !Span
  , referenceSymbol :: !SymbolId
  }
  deriving stock (Eq, Show)

{-| Shadowing an immutable local is silent, and so is shadowing a wired-in or
    prelude name — a module is expected to define its own `Drop` or `from` if it
    wants one. Every origin the language calls out stays warned. -}
isShadowWarned :: Symbol -> Bool
isShadowWarned symbol =
  symbolMutable symbol
    || symbolOrigin symbol `elem` [ParameterOrigin, ImportOrigin, TypeParamOrigin, ModuleOrigin]
