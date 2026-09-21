{-| @Type.Module — exposes the typing boundary -}
module Pudu.Type
  ( ModuleTypes (..)
  , Scheme (..)
  , Type (..)
  , TypeInfo (..)
  , checkTypes
  , checkTypesDetailed
  , checkTypesWith
  , renderType
  , typeAt
  , narrowestAt
  , narrowestSpanAt
  , widestWithin
  ) where

import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import Pudu.Diagnostic (Diagnostic)
import Pudu.Semantic (resolveModule, writableReferences)
import Pudu.Frontend.Syntax.Tree (Module)
import Pudu.Source (Span, spanEnd, spanStart, unOffset)
import Pudu.Type.Check (checkModule)
import qualified Pudu.Type.Check as Check
import Pudu.Type.Interface.Graph (ImportTypes)
import Pudu.Type.Value (NominalId, Scheme (..), Type (..), renderType)
import Data.Text (Text)

{-| @Type.Info — the type each checked expression was given, keyed by the span
    it occupies. Tooling reads it to answer "what is this?" without re-running
    the checker. -}
newtype TypeInfo = TypeInfo (Map (Int, Int) Type)
  deriving stock (Eq, Show)

checkTypes :: Module -> (TypeInfo, [Diagnostic])
checkTypes moduleValue =
  let (entries, diagnostics) = checkModule (writableIn moduleValue) moduleValue
   in (TypeInfo (Map.fromList entries), diagnostics)

{-| The uses of `var` bindings, for a caller that has not resolved the module
    itself. The checker takes them from resolution rather than scoping names a
    second time. -}
writableIn :: Module -> Set (Int, Int)
writableIn = writableReferences . fst . resolveModule

{-| @Type.ModuleTypes — one check's full result.

    `moduleSchemes` is the compiler's own answer for every module-scope name:
    the generalised type inference settled on, with the bounds it must prove.
    Documentation and search read it so that what a tool reports and what the
    compiler believes cannot disagree. -}
data ModuleTypes = ModuleTypes
  { moduleTypeInfo :: !TypeInfo
  , moduleSchemes :: ![(Text, Scheme)]
  {-| What inference settled on for each integer literal, by span.

      A literal written without a suffix is not a platform `Int` merely because
      it was written plainly, and only the checker knows what it became. -}
  , moduleIntegerKinds :: !(Map.Map Span Text)
  {-| The methods this module's declarations provide, by owner: its impls'
      methods and the trait defaults they inherit, and its traits' members. -}
  , moduleMethods :: ![(NominalId, Text, Scheme)]
  }
  deriving stock (Eq, Show)

checkTypesDetailed :: ImportTypes -> Set (Int, Int) -> Module -> (ModuleTypes, [Diagnostic])
checkTypesDetailed imported writable moduleValue =
  let (entries, schemes, kinds, methods, diagnostics) = Check.checkModuleDetailed imported writable moduleValue
   in ( ModuleTypes
          { moduleTypeInfo = TypeInfo (Map.fromList entries)
          , moduleSchemes = schemes
          , moduleIntegerKinds = Map.fromList kinds
          , moduleMethods = methods
          }
      , diagnostics
      )

checkTypesWith :: ImportTypes -> Module -> (TypeInfo, [Diagnostic])
checkTypesWith imported moduleValue =
  let (entries, diagnostics) = Check.checkModuleWith imported (writableIn moduleValue) moduleValue
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

{-| The type of the smallest expression covering this offset.

    What a reader points at is the innermost thing there — hovering `text` in
    `text.length()` asks about `text`, not about the call that contains it, and
    not about the function that contains that. -}
narrowestAt :: Int -> TypeInfo -> Maybe Type
narrowestAt offset info = snd <$> narrowestSpanAt offset info

{-| The smallest expression covering this offset, with the span it occupies. -}
narrowestSpanAt :: Int -> TypeInfo -> Maybe ((Int, Int), Type)
narrowestSpanAt offset (TypeInfo entries) = Map.foldlWithKey' narrower Nothing entries
 where
  -- One pass keeping the shortest covering span; the first of equal widths,
  -- in key order, wins.
  narrower best key@(from, to) found
    | from > offset || offset > to = best
    | otherwise = case best of
        Just ((bestFrom, bestTo), _) | bestTo - bestFrom <= to - from -> best
        _ -> Just (key, found)

{-| The type recorded for the expression occupying exactly this span. -}
typeAt :: TypeInfo -> Span -> Maybe Type
typeAt (TypeInfo entries) spanValue =
  Map.lookup (unOffset (spanStart spanValue), unOffset (spanEnd spanValue)) entries
