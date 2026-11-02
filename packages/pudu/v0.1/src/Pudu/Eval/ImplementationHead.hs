{-| @Eval.ImplementationHead — immutable checked head metadata shared by installed methods. -}
module Pudu.Eval.ImplementationHead
  ( HeadSelection (..), ImplementationHead (..) ) where

import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located)
import Pudu.Frontend.Syntax.Tree (TypeSyntax)

{-| Selected heads reserve later explicit arguments for method-local parameters. -}
data HeadSelection = PendingHead | SelectedHead
  deriving stock (Eq, Show)

{-| Binder order is declaration order; the target is already canonical and alias-expanded. -}
data ImplementationHead = ImplementationHead
  { headParameters :: ![Text]
  , headTarget :: !(Located TypeSyntax)
  , headSelection :: !HeadSelection
  }
  deriving stock (Eq, Show)
