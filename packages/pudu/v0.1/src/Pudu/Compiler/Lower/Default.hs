{-| @Pudu.Compiler.Lower.Default — functions with default parameter values.
    Such a function takes one more parameter: how many arguments the call
    supplied. Its body opens by giving every parameter the call did not reach
    its default, in order, so a default sees the parameters before it. -}
module Pudu.Compiler.Lower.Default (hasDefaults, suppliedArguments, lowerDefaultedBody) where

import Data.Maybe (isJust)
import Pudu.Compiler.Lower.State (CoreSignature (..), LowerState, intType, refuse)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Function (..), Located (..), Parameter (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerBody = Located Function -> CoreSignature -> LowerState -> (LowerState, Maybe CoreFunction)

hasDefaults :: Function -> Bool
hasDefaults function = any (isJust . parameterDefault . locatedValue) (functionParameters function)

{-| What a call passes to a function with defaults: the arguments it wrote,
    a zero for each parameter it left out, then how many it wrote. The types
    are the callee's parameters, the count's included. -}
suppliedArguments :: Span -> [CoreType] -> [CoreExpression] -> [CoreExpression]
suppliedArguments at parameterTypes given =
  given
    <> [CoreExpression at kind CoreAbsent | kind <- drop (length given) (take (length parameterTypes - 1) parameterTypes)]
    <> [CoreExpression at intType (CoreIntegerLiteral PlatformSigned (toInteger (length given)))]

{-| The body with its defaults in front. A default is lowered in the
    callee, after the parameters before it are in scope. -}
lowerDefaultedBody :: LowerExpression -> LowerBody -> LowerBody
lowerDefaultedBody lower lowerBody located signature state = case foldl' fill (state, Just []) defaults of
  (after, Nothing) -> (after, Nothing)
  (after, Just prologue) -> case lowerBody located signature after of
    (final, Just lowered) ->
      let body = coreFunctionBody lowered
       in (final, Just lowered{coreFunctionBody = body{coreBlockStatements = prologue <> coreBlockStatements body}})
    other -> other
 where
  locals = map coreParameterLocal (signatureParameters signature)
  supplied = last locals
  defaults =
    [ (index, local, value)
    | (index, Located _ parameter, local) <- zip3 [0 :: Integer ..] (functionParameters (locatedValue located)) locals
    , Just value <- [parameterDefault parameter] ]
  fill (current, Nothing) _ = (current, Nothing)
  fill (current, Just done) (index, local, value) = case lower current value of
    (after, Just (core, kind))
      | kind == coreLocalType local || kind == CoreNeverType ->
          let at = locatedSpan value
              count = CoreExpression at intType (CoreReadLocal supplied)
              position = CoreExpression at intType (CoreIntegerLiteral PlatformSigned index)
              missing = CoreExpression at CoreBoolType (CoreBinary CoreLessOrEqual count position)
              assigned = CoreBlock [CoreStatement at (CoreAssign local core)] Nothing
           in (after, Just (done <> [CoreStatement at (CoreIf missing assigned Nothing)]))
      | otherwise -> (refuse (locatedSpan value) ("a default of type " <> coreTypeName kind) after, Nothing)
    (after, Nothing) -> (after, Nothing)
