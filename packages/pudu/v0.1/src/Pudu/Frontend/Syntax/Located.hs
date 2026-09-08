{-| @Program.Syntax.Located — preserves uniform source provenance -}
module Pudu.Frontend.Syntax.Located
  ( Located (..)
  , mapLocated
  , mergeLocatedSpan
  ) where

import Pudu.Source (Span, mergeSpans)

{-| @Program.Syntax.Node — pairs syntax with exact provenance -}
data Located a = Located
  { locatedSpan :: !Span
  , locatedValue :: !a
  }
  deriving stock (Eq, Show, Functor)

mapLocated :: (a -> b) -> Located a -> Located b
mapLocated transform Located{locatedSpan, locatedValue} =
  Located{locatedSpan, locatedValue = transform locatedValue}

mergeLocatedSpan :: Located a -> Located b -> Maybe Span
mergeLocatedSpan left right = mergeSpans (locatedSpan left) (locatedSpan right)
