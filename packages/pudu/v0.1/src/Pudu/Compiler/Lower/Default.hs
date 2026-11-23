{-| @Pudu.Compiler.Lower.Default — functions with default parameter values.
    Such a function takes one more parameter: how many arguments the call
    supplied. Its body opens by giving every parameter the call did not reach
    its default, in order, so a default sees the parameters before it. -}
module Pudu.Compiler.Lower.Default (takesSuppliedCount, trailingDefaults, suppliedArguments, callArityFailure, lowerDefaultedBody) where

import Data.Maybe (isJust)
import Pudu.Compiler.Lower.Arguments (ArgumentBlame (AtCaller), argumentFailureWith)
import Pudu.Compiler.Lower.Dynamic (projectRuntimeValue)
import Pudu.Compiler.Lower.State (CoreSignature (..), LowerContext (..), LowerState (..), intType, refuse)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Function (..), Located (..), Parameter (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerBody = Located Function -> CoreSignature -> LowerState -> (LowerState, Maybe CoreFunction)

takesSuppliedCount :: CoreSignature -> Bool
takesSuppliedCount = any ((== suppliedCountName) . coreLocalName . coreParameterLocal) . signatureParameters

{-| Each parameter's default when it belongs to the trailing run a call may
    omit. A default written before a parameter without one is never used: the
    checker requires an argument there. -}
trailingDefaults :: Function -> [Maybe (Located Expression)]
trailingDefaults function = map (const Nothing) required <> map (parameterDefault . locatedValue) (reverse omissible)
 where
  (omissible, required) = span (isJust . parameterDefault . locatedValue) (reverse (functionParameters function))

{-| What a call passes to a function with defaults: the arguments it wrote,
    a zero for each parameter it left out, then how many it wrote. The types
    are the callee's parameters, the count's included. -}
suppliedArguments :: Span -> [CoreType] -> [CoreExpression] -> [CoreExpression]
suppliedArguments at parameterTypes given =
  given
    <> [CoreExpression at kind CoreAbsent | kind <- drop (length given) (take (length parameterTypes - 1) parameterTypes)]
    <> [CoreExpression at intType (CoreIntegerLiteral PlatformSigned (toInteger (length given)))]

callArityFailure :: ArgumentBlame -> Span -> CoreSignature -> Int -> Maybe CoreExpression
callArityFailure blame at signature supplied
  | supplied > written = Just (failure "too many arguments in call" "pass one argument per declared parameter")
  | defaulted = Nothing
  | parameter : _ <- drop supplied (signatureParameters signature) =
      let name = coreLocalName (coreParameterLocal parameter)
       in Just (failure ("missing argument for parameter " <> name) "supply the argument or give the parameter a default")
  | otherwise = Nothing
 where
  defaulted = takesSuppliedCount signature
  written = length (signatureParameters signature) - if defaulted then 1 else 0
  failure message help =
    argumentFailureWith blame at "E7003" (Just help) (CoreExpression at CoreTextType (CoreTextLiteral message))

{-| The body with its defaults in front. A default is lowered in the
    callee, after the parameters before it are in scope. -}
lowerDefaultedBody :: LowerExpression -> LowerBody -> LowerBody
lowerDefaultedBody lower lowerBody located signature state =
  case reverse (map coreParameterLocal (signatureParameters signature)) of
    supplied : parameters
      | coreLocalName supplied == suppliedCountName ->
          let bindings = zip3 [0 :: Integer ..] (reverse parameters) (functionParameters (locatedValue located))
           in case foldl' (fill supplied) (state, Just []) bindings of
                (after, Nothing) -> (after, Nothing)
                (after, Just prologue) -> case lowerBody located signature after of
                  (final, Just lowered) ->
                    let body = coreFunctionBody lowered
                     in (final, Just lowered{coreFunctionBody = body{coreBlockStatements = reverse prologue <> coreBlockStatements body}})
                  other -> other
    _ -> lowerBody located signature state
 where
  fill _ (current, Nothing) _ = (current, Nothing)
  fill supplied (current, Just done) (index, local, Located parameterAt parameter) =
    case parameterDefault parameter of
      Nothing ->
        let name = locatedValue (parameterName parameter)
            message = CoreExpression parameterAt CoreTextType (CoreTextLiteral ("missing argument for parameter " <> name))
            failure = argumentFailureWith AtCaller parameterAt "E7003"
              (Just "supply the argument or give the parameter a default") message
         in (current, Just (whenMissing supplied parameterAt index (CoreEvaluate failure) : done))
      Just value -> case lower current value of
        (after, Nothing) -> (after, Nothing)
        (after, Just (lowered, _)) ->
          let at = locatedSpan value
              (ready, core) = projectRuntimeValue (contextTypes (lowerContext after)) after (coreLocalType local) lowered
              kind = coreExpressionType core
           in if kind == coreLocalType local || kind == CoreNeverType
                then (ready, Just (whenMissing supplied at index (CoreAssign local core) : done))
                else (refuse at ("a default of type " <> coreTypeName kind) ready, Nothing)
  whenMissing supplied at index action =
    let count = CoreExpression at intType (CoreReadLocal supplied)
        position = CoreExpression at intType (CoreIntegerLiteral PlatformSigned index)
        missing = CoreExpression at CoreBoolType (CoreBinary CoreLessOrEqual count position)
     in CoreStatement at (CoreIf missing (CoreBlock [CoreStatement at action] Nothing) Nothing)
