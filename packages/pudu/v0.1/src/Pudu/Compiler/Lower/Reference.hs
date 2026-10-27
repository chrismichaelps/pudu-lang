{-| @Compiler.Lower.Reference — checked shared references use value carriers. -}
module Pudu.Compiler.Lower.Reference (lowerReference) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), halt, refused)
import Pudu.Compiler.Lower.Types (sharedReferenceTarget, typeForSpan)
import Pudu.Core (CoreExpression, CoreType (..))
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

{-| Keep the operand's provenance: borrowing itself cannot fail, but taking
    the value to borrow may already transfer control or report a diagnostic. -}
lowerReference
  :: (LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType)))
  -> LowerState -> Span -> Text -> Located Expression
  -> (LowerState, Maybe (CoreExpression, CoreType))
lowerReference lower state at operator operand = case lower state operand of
  (after, Nothing) -> refused after
  (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
  (after, Just (core, kind))
    | expressionIsPrintValued core -> halt at "borrowing a Result[(), Str] value" after
    | let types = contextTypes (lowerContext after)
    , (case operator of
        "&" -> sharedReferenceTarget types at == Just kind
        "*" -> sharedReferenceTarget types (locatedSpan operand) == Just kind
          && typeForSpan types at == Just kind
        _ -> False) -> (after, Just (core, kind))
    | otherwise -> halt at "a shared reference without matching solved type facts" after
