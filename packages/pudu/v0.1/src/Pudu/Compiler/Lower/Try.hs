{-| @Pudu.Compiler.Lower.Try — `value?` as a match on the success variant. -}
module Pudu.Compiler.Lower.Try (lowerTry, unwrapOrLeave) where

import qualified Data.Set as Set
import Data.List (find)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Dynamic (mapRuntimeChoice, projectRuntimeValue, runtimeCarriers)
import Pudu.Compiler.Lower.Loan (loanedValue)
import Pudu.Compiler.Lower.Drop (droppingAll)
import Pudu.Compiler.Lower.Scope (leaving)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, refused)
import Pudu.Compiler.Lower.Sum (constructVariant)
import Pudu.Compiler.Lower.Types (sumVariants)
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
  | Just selected <- mapRuntimeChoice after at CoreNeverType core
      (\current held -> fmap (fmap fst) (unwrapOrLeave current at held (coreExpressionType held))) = selected
  | CoreSumType owner _ <- kind
  , Just result <- returning
  , let candidates = [candidate | candidate@(CoreSumType family _) <- Set.toAscList (runtimeCarriers result), family == owner]
  , not (null candidates)
  , Just variants <- sumVariants types kind
  , Just (good, success, bad, failure) <- continuation owner variants =
      unwrap after core good success bad failure result candidates
  | otherwise = halt at ("? on a " <> coreTypeName kind <> " in a function returning " <> maybe "an unknown type" coreTypeName returning) after
 where
  returning = maybe (lowerDeclaredResult after) Just (lowerFunctionResult after)
  types = contextTypes (lowerContext after)
  continuation owner variants
    | owner == "Result"
    , Just [(_, success)] <- fields "Ok"
    , Just [(_, failure)] <- fields "Err" = Just ("Ok", success, "Err", Just failure)
    | owner == "Option"
    , Just [(_, success)] <- fields "Some"
    , Just [] <- fields "None" = Just ("Some", success, "None", Nothing)
    | otherwise = Nothing
   where
    fields label = coreVariantFields <$> find ((== label) . coreVariantName) variants
  unwrap current held good success bad failure expected candidates =
    let opened = current{lowerScopes = [] : lowerScopes current}
        (withValue, value) = bindLocal opened "" success
        (withFailure, failed) = case failure of
          Just failureKind -> fmap Just (bindLocal withValue "" failureKind)
          Nothing -> (withValue, Nothing)
        closed = withFailure{lowerScopes = drop 1 (lowerScopes withFailure)}
        reading local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
        payload = [("0", reading local) | Just local <- [failed]]
     in case failureValue closed expected candidates bad payload of
          (ready, Just rebuilt) ->
            let recorded
                  | lowerFlexibleResult ready = ready
                      {lowerObservedReturns = lowerObservedReturns ready <> runtimeCarriers (coreExpressionType rebuilt)}
                  | otherwise = ready
                (left, returned) = loanedValue recorded at rebuilt
                -- The failure is in hand before the scopes it leaves are joined.
                (withKept, kept) = bindLocal left "" (coreExpressionType returned)
                (released, drops) = droppingAll withKept at
                (joined, joins) = fmap (drops <>) (leaving released at)
                leave = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
                  (if null joins then [CoreStatement at (CoreReturn (Just returned))]
                   else [CoreStatement at (CoreDeclare kept returned)] <> joins
                     <> [CoreStatement at (CoreReturn (Just (reading kept)))]) Nothing))
                arms =
                  [ CoreArm at (CoreVariantPattern good [CoreBindPattern value]) Nothing (reading value)
                  , CoreArm at (CoreVariantPattern bad (map CoreBindPattern (foldMap pure failed))) Nothing leave ]
             in (if null joins then left else joined, Just (CoreExpression at success (CoreMatch held arms), success))
          (ready, Nothing) -> refused ready
  failureValue current expected candidates bad payload = choose candidates Nothing
   where
    choose [] (Just fallback) | lowerFlexibleResult current = fmap Just fallback
    choose [] _ = halt at "a propagated failure with an incompatible return layout" current
    choose (candidate : rest) fallback = case constructVariant current at candidate bad payload of
      (ready, Just (rebuilt, _)) ->
        let (projected, value) = projectRuntimeValue types ready expected rebuilt
         in if coreExpressionType value == expected
              then (projected, Just value)
              else choose rest (Just (ready, rebuilt))
      (_, Nothing) -> choose rest fallback
