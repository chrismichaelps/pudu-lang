{-| @Ownership.Marks — how settled facts mark ownership for the engines

    Ownership checking decides which uses move a value that needs drop and
    which binders own one. Both facts reach the interpreter and native
    lowering with the settled module and its span facts, so a cached module
    carries them exactly as a freshly checked one does. -}
module Pudu.Ownership
  ( moveOperator
  , ownedBinderKind
  ) where

import Data.Text (Text)

{-| The unary operator settled syntax wraps around a use of a local that moves
    a value needing drop. No source spelling produces it. -}
moveOperator :: Text
moveOperator = "::move"

{-| The span fact a binder that owns a value needing drop carries, beside the
    integer literal kinds in the same map: the two never share a span. -}
ownedBinderKind :: Text
ownedBinderKind = "::owned"
