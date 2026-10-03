{-| @Derive.State — bounded request-owned syntax identity and field obligations. -}
module Pudu.Derive.State
  ( ExpansionFailure (..), FieldObligation (..), Residual
  , generated, iteration, refuse, requireFields, runResidual, withinDepth
  ) where

import Data.Text (Text)
import Pudu.Comptime.Limits (callDepthLimit, expansionNodeLimit, iterationLimit)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (TypeSyntax)
import Pudu.Source (Span, generatedSpan)

data ExpansionFailure = ExpansionFailure !Span !Text
  deriving stock (Eq, Show)

data FieldObligation = FieldObligation
  { obligationField :: !Span
  , obligationType :: !(Located TypeSyntax)
  , obligationBounds :: ![Located TypeSyntax]
  , obligationRequest :: !Span
  }
  deriving stock (Eq, Show)

data ResidualState = ResidualState
  { requestAnchor :: !Span
  , nextNode :: !Int
  , iterations :: !Int
  , obligationsRev :: ![FieldObligation]
  }

newtype Residual a = Residual
  (ResidualState -> Either ExpansionFailure (a, ResidualState))

instance Functor Residual where
  fmap transform (Residual action) = Residual $ \state -> do
    (value, next) <- action state
    pure (transform value, next)

instance Applicative Residual where
  pure value = Residual $ \state -> Right (value, state)
  Residual left <*> Residual right = Residual $ \state -> do
    (transform, afterLeft) <- left state
    (value, afterRight) <- right afterLeft
    pure (transform value, afterRight)

instance Monad Residual where
  Residual action >>= continue = Residual $ \state -> do
    (value, next) <- action state
    let Residual remaining = continue value
    remaining next

runResidual :: Span -> Residual a -> Either ExpansionFailure (a, [FieldObligation])
runResidual request (Residual action) = do
  (value, final) <- action (ResidualState request 0 0 [])
  pure (value, reverse (obligationsRev final))

generated :: Span -> a -> Residual (Located a)
generated definition value = Residual $ \state ->
  if nextNode state >= expansionNodeLimit
    then Left (failure state definition "derive expansion exhausted its generated-node budget")
    else Right
      ( Located (generatedSpan (nextNode state) definition (requestAnchor state)) value
      , state{nextNode = nextNode state + 1}
      )

refuse :: Span -> Text -> Residual a
refuse at message = Residual $ \state -> Left (failure state at message)

failure :: ResidualState -> Span -> Text -> ExpansionFailure
failure state at = ExpansionFailure (generatedSpan (nextNode state) at (requestAnchor state))

iteration :: Span -> Residual ()
iteration at = Residual $ \state ->
  if iterations state >= iterationLimit
    then Left (failure state at "derive expansion exhausted its compile-time iteration budget")
    else Right ((), state{iterations = iterations state + 1})

withinDepth :: Int -> Span -> Residual ()
withinDepth depth at
  | depth >= callDepthLimit = refuse at "derive expansion exhausted its compile-time depth budget"
  | otherwise = pure ()

requireFields :: Span -> Located TypeSyntax -> [Located TypeSyntax] -> Residual ()
requireFields at written bounds = Residual $ \state ->
  let obligation = FieldObligation at written bounds (requestAnchor state)
   in Right ((), state{obligationsRev = obligation : obligationsRev state})
