{-| @Foreign.Extent — checked relations between a length and its buffers. -}
module Pudu.Foreign.Extent
  ( ExtentUnit (..)
  , ForeignBound (..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import GHC.Generics (Generic)

data ExtentUnit = ExtentElements | ExtentBytes
  deriving stock (Eq, Ord, Show, Generic)

{-| Declaration order and target order determine the first reported failure. -}
data ForeignBound = ForeignBound
  { boundLength :: !Int
  , boundUnit :: !ExtentUnit
  , boundTargets :: !(NonEmpty Int)
  }
  deriving stock (Eq, Ord, Show)
