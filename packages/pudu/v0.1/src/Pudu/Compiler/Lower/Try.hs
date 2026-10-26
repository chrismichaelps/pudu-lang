{-| @Pudu.Compiler.Lower.Try — `value?` as a match on the success variant. -}
module Pudu.Compiler.Lower.Try (lowerTry) where

import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerState (..), bindLocal, halt, refused)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

{-| `Ok(v)` and `Some(v)` give `v`; `Err(e)` and `None` return from the
    enclosing function, as the evaluator's `unwrapTry` does. The failure is
    built again at the function's own result type: `Err(e)` of a
    `Result[Int, E]` returned from a `Result[Str, E]` function is the same
    value, but a different native layout. -}
lowerTry :: LowerExpression -> LowerState -> Span -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
lowerTry lower state at operand = case lower state operand of
  (after, Nothing) -> refused after
  (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
  (after, Just (core, kind))
    | expressionIsPrintValued core -> halt at "? on a Result[(), Str] value" after
    | otherwise -> case (kind, returning) of
        (CoreSumType "Result" [success, failure], Just result@(CoreSumType "Result" [_, returned]))
          | failure == returned -> unwrap after core success "Ok" (Just ("Err", failure)) result
        (CoreSumType "Option" [success], Just result@(CoreSumType "Option" [_])) ->
          unwrap after core success "Some" Nothing result
        _ -> halt at ("? on a " <> coreTypeName kind <> " in a function returning " <> maybe "an unknown type" coreTypeName returning) after
     where
      returning = maybe (lowerDeclaredResult after) Just (lowerFunctionResult after)
 where
  unwrap current core success good bad result =
    let opened = current{lowerScopes = [] : lowerScopes current}
        (withValue, value) = bindLocal opened "" success
        (withFailure, failed) = case bad of
          Just (_, failure) -> fmap Just (bindLocal withValue "" failure)
          Nothing -> (withValue, Nothing)
        closed = withFailure{lowerScopes = drop 1 (lowerScopes withFailure)}
        reading local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
        rebuilt = case (bad, failed) of
          (Just (name, _), Just local) -> CoreConstruct name [("0", reading local)]
          _ -> CoreConstruct "None" []
        leave = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
          [CoreStatement at (CoreReturn (Just (CoreExpression at result rebuilt)))] Nothing))
        failing = case (bad, failed) of
          (Just (name, _), Just local) -> CoreVariantPattern name [CoreBindPattern local]
          _ -> CoreVariantPattern "None" []
        arms =
          [ CoreArm at (CoreVariantPattern good [CoreBindPattern value]) Nothing (reading value)
          , CoreArm at failing Nothing leave ]
     in (closed, Just (CoreExpression at success (CoreMatch core arms), success))
