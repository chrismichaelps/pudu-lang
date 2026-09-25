{-| @Program.Syntax.Located — preserves uniform source provenance -}
module Pudu.Frontend.Syntax.Located
  ( Located (..)
  , mapLocated
  , mergeLocatedSpan
  ) where

import GHC.Generics (Generic)
import Pudu.Cache.Persist (Persist)
import Pudu.Source (Span, mergeSpans)

{-| @Program.Syntax.Node — pairs syntax with exact provenance -}
data Located a = Located
  { locatedSpan :: !Span
  , locatedValue :: !a
  }
  deriving stock (Eq, Show, Functor, Generic)

mapLocated :: (a -> b) -> Located a -> Located b
mapLocated transform Located{locatedSpan, locatedValue} =
  Located{locatedSpan, locatedValue = transform locatedValue}

mergeLocatedSpan :: Located a -> Located b -> Maybe Span
mergeLocatedSpan left right = mergeSpans (locatedSpan left) (locatedSpan right)

instance Persist a => Persist (Located a)
