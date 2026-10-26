{-| @Pudu.Compiler.Lower.Convert — `convertInteger[T](value)`. The value runs
    into a local, then a fit test picks `Some` of the converted value or
    `None`, as `callConvertInteger` answers. -}
module Pudu.Compiler.Lower.Convert (lowerConvertInteger) where

import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, refused)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

{-| The target is read from the call's checked `Option[T]`. -}
lowerConvertInteger :: LowerExpression -> LowerState -> Span -> [Located Expression] -> (LowerState, Maybe (CoreExpression, CoreType))
lowerConvertInteger lower state at arguments = case (typeForSpan (contextTypes (lowerContext state)) at, arguments) of
  (Just option@(CoreSumType _ [target@(CoreIntegerType kind)]), [argument]) -> case lower state argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, CoreIntegerType _))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | otherwise ->
          let (withHeld, held) = bindLocal after "" (coreExpressionType core)
              expression shape kind' = CoreExpression at kind' shape
              value = expression (CoreReadLocal held) (coreExpressionType core)
              some = expression (CoreConstruct "Some" [("0", expression (CoreIntegerConvert kind value) target)]) option
              none = expression (CoreConstruct "None" []) option
              choice = expression (CoreIfValue (expression (CoreIntegerFits kind value) CoreBoolType) (CoreBlock [] (Just some)) none) option
           in (withHeld, Just (expression (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare held core)] (Just choice))) option, option))
    (after, Just (_, kind')) -> halt (locatedSpan argument) ("convertInteger from a " <> coreTypeName kind') after
  _ -> halt at "this convertInteger call" state
