{-| @Pudu.Compiler.Lower.Call — direct calls to module functions and the
    builtins `print`, `display` and `show`. -}
module Pudu.Compiler.Lower.Call (lowerFunctionCall, lowerPrint, outputResult, lowerRendered) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Default (hasDefaults, suppliedArguments)
import Pudu.Compiler.Lower.Generic (admitCallee)
import Pudu.Compiler.Lower.Scalar (eagerType)
import Pudu.Compiler.Lower.State (CoreSignature (..), LowerContext (..), LowerState (..), bindLocal, halt, refused)
import Pudu.Compiler.Lower.Types (nativeValueType, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| A call to a function of any module: its signature is admitted under that
    module's facts, then the arguments run here, in the caller's. -}
lowerFunctionCall :: LowerExpression -> LowerState -> Span -> Text -> Span -> [Located Expression] -> Lowered
lowerFunctionCall lower state at key callee arguments = case lookup key (contextTable (lowerContext state)) of
  Nothing -> halt at "this call" state
  Just entry
    | key == contextEntry (lowerContext state) -> halt at "a call to the entry function" state
    | otherwise -> case admitCallee state key callee entry of
        (back, Nothing) -> refused back
        (back, Just (target, found)) -> case collect back [] arguments of
          (final, Just cores)
            | any ((== CoreNeverType) . coreExpressionType) cores ->
                typed final (CoreBlockValue (CoreBlock
                  [CoreStatement (coreExpressionSpan argument) (CoreEvaluate argument) | argument <- cores] Nothing)) CoreNeverType
            | otherwise ->
                let queued = final{lowerContext = (lowerContext final){contextQueue = target : contextQueue (lowerContext final)}}
                    passed
                      | hasDefaults (locatedValue (snd entry)) =
                          suppliedArguments at (map (coreLocalType . coreParameterLocal) (signatureParameters found)) cores
                      | otherwise = cores
                 in typed queued (CoreCall target passed) (eagerType (signatureResult found) cores)
          (final, Nothing) -> refused final
 where
  typed after shape kind = (after, Just (CoreExpression at kind shape, kind))
  collect current done [] = (current, Just (reverse done))
  collect current done (argument : rest) = case lower current argument of
    (after, Just (core, _))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | otherwise -> collect after (core : done) rest
    (after, Nothing) -> (after, Nothing)

{-| Standard-stream output keeps its checked Result. The internal write
    outcome is bound once before either variant is constructed. -}
lowerPrint :: LowerExpression -> LowerState -> Span -> Text -> [Located Expression] -> Lowered
lowerPrint lower state at name arguments = case arguments of
  [argument] -> case lower state argument of
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, CoreTextType)) -> case typeForSpan (contextTypes (lowerContext after)) at of
      Just result@(CoreSumType "Result" [CoreUnitType, CoreTextType]) ->
        outputResult after at name core result
      _ -> halt at "output without a represented Result[(), Str] type" after
    (after, Just (_, kind)) -> halt at ("printing a " <> coreTypeName kind <> " value") after
    (after, Nothing) -> refused after
  _ -> halt at ("a call to " <> name <> " with this many arguments") state

outputResult :: LowerState -> Span -> Text -> CoreExpression -> CoreType -> Lowered
outputResult state at name core result =
  let (bound, outcome) = bindLocal state "" CoreTextType
      expression = CoreExpression at
      reading = expression CoreTextType (CoreReadLocal outcome)
      empty = expression CoreTextType (CoreTextLiteral "")
      succeeded = expression CoreBoolType (CoreBinary CoreEqual reading empty)
      unit = expression CoreUnitType (CoreBlockValue (CoreBlock [] Nothing))
      ok = expression result (CoreConstruct "Ok" [("0", unit)])
      failure = expression result (CoreConstruct "Err" [("0", reading)])
      selected = expression result (CoreIfValue succeeded (CoreBlock [] (Just ok)) failure)
      write = expression CoreTextType (CoreOutputError
        (name `elem` ["printError", "printErrorPart"])
        (name `elem` ["print", "printError"]) core)
   in (bound, Just (expression result (CoreBlockValue
        (CoreBlock [CoreStatement at (CoreDeclare outcome write)] (Just selected))), result))

{-| `display(value)` or `show(value)` as text. -}
lowerRendered :: LowerExpression -> LowerState -> Span -> Text -> (CoreExpression -> CoreExpressionShape) -> [Located Expression] -> Lowered
lowerRendered lower state at name shape arguments = case arguments of
  [argument] -> case lower state argument of
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, _))
      | expressionIsPrintValued core -> halt at (name <> " of a Result[(), Str] value") after
    (after, Just (core, kind))
      | nativeValueType kind -> (after, Just (CoreExpression at CoreTextType (shape core), CoreTextType))
      | otherwise -> halt at (name <> " of a " <> coreTypeName kind <> " value") after
    (after, Nothing) -> refused after
  _ -> halt at ("a call to " <> name <> " with this many arguments") state
