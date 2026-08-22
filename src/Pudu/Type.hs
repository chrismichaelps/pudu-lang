{-| @Type.Module — exposes the typing boundary -}
module Pudu.Type
  ( Scheme (..)
  , Type (..)
  , TypeInfo (..)
  , checkTypes
  , renderType
  , typeAt
  , widestWithin
  ) where

import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Pudu.Diagnostic (Diagnostic)
import Pudu.Frontend.Syntax.Tree (Module)
import Pudu.Source (Span, spanEnd, spanStart, unOffset)
import Pudu.Type.Check (checkModule)
import Pudu.Type.Value (Scheme (..), Type (..), renderType)

{-| @Type.Info — the type each checked expression was given, keyed by the span
    it occupies. Tooling reads it to answer "what is this?" without re-running
    the checker. -}
newtype TypeInfo = TypeInfo (Map (Int, Int) Type)
  deriving stock (Eq, Show)

checkTypes :: Module -> (TypeInfo, [Diagnostic])
checkTypes moduleValue =
  let (entries, diagnostics) = checkModule moduleValue
   in (TypeInfo (Map.fromList entries), diagnostics)

{-| The type of the widest expression the checker typed inside a region of the
    source. Tooling uses it to answer "what is this?" for a span it knows only
    approximately, such as one line of an interactive entry. -}
widestWithin :: Int -> Int -> TypeInfo -> Maybe Type
widestWithin start end (TypeInfo entries) =
  case widest of
    [] -> Nothing
    (_, found) : _ -> Just found
 where
  contained ((from, to), _) = from >= start && to <= end
  widest =
    sortOn (\((from, to), _) -> from - to) (filter contained (Map.toList entries))

{-| The type recorded for the expression occupying exactly this span. -}
typeAt :: TypeInfo -> Span -> Maybe Type
typeAt (TypeInfo entries) spanValue =
  Map.lookup (unOffset (spanStart spanValue), unOffset (spanEnd spanValue)) entries
