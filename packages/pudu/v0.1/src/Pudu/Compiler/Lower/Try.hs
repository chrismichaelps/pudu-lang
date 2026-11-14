{-| @Pudu.Compiler.Lower.Try — `value?` as a match on the success variant. -}
module Pudu.Compiler.Lower.Try (lowerTry, unwrapOrLeave) where

import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Loan (loanedValue)
import Pudu.Compiler.Lower.Scope (leaving)
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
  (after, Just (core, kind)) -> unwrapOrLeave after at core kind

{-| The same on a value already lowered, which `.await` shares: a task that
    answers a failure leaves the awaiting function with it. -}
unwrapOrLeave :: LowerState -> Span -> CoreExpression -> CoreType -> (LowerState, Maybe (CoreExpression, CoreType))
unwrapOrLeave after at core kind
  | kind == CoreNeverType = (after, Just (core, CoreNeverType))
  | expressionIsPrintValued core = halt at "? on a Result[(), Str] value" after
  | otherwise = case (kind, returning) of
        (CoreSumType "Result" [success, failure], Just result@(CoreSumType "Result" [_, returned]))
          | failure == returned -> unwrap after core success "Ok" (Just ("Err", failure)) result
        (CoreSumType "Option" [success], Just result@(CoreSumType "Option" [_])) ->
          unwrap after core success "Some" Nothing result
        _ -> halt at ("? on a " <> coreTypeName kind <> " in a function returning " <> maybe "an unknown type" coreTypeName returning) after
 where
  returning = maybe (lowerDeclaredResult after) Just (lowerFunctionResult after)
  unwrap current held success good bad result =
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
        (left, returned) = loanedValue closed at (CoreExpression at result rebuilt)
        -- The failure is in hand before the scopes it leaves are joined.
        (withKept, kept) = bindLocal left "" result
        (joined, joins) = leaving withKept at
        leave = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
          (if null joins then [CoreStatement at (CoreReturn (Just returned))]
           else [CoreStatement at (CoreDeclare kept returned)] <> joins
             <> [CoreStatement at (CoreReturn (Just (CoreExpression at result (CoreReadLocal kept))))]) Nothing))
        failing = case (bad, failed) of
          (Just (name, _), Just local) -> CoreVariantPattern name [CoreBindPattern local]
          _ -> CoreVariantPattern "None" []
        arms =
          [ CoreArm at (CoreVariantPattern good [CoreBindPattern value]) Nothing (reading value)
          , CoreArm at failing Nothing leave ]
     in (if null joins then left else joined, Just (CoreExpression at success (CoreMatch held arms), success))
