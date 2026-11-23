{-| @Pudu.Compiler.Lower.Call — direct calls to module functions and the
    builtins `print`, `display` and `show`. -}
module Pudu.Compiler.Lower.Call (lowerFunctionCall, lowerPrint, outputResult, outputText, lowerRendered) where

import Data.Text (Text)
import Data.List (mapAccumL)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Default (takesSuppliedCount, suppliedArguments)
import Pudu.Compiler.Lower.Generic (admitCalleeGiven, runtimeCallSignature)
import Pudu.Compiler.Lower.Loan (lowerLoanedCall)
import Pudu.Compiler.Lower.Scalar (eagerType)
import Pudu.Compiler.Lower.State (CoreSignature (..), LowerContext (..), LowerState (..), bindLocal, halt, refused)
import Pudu.Compiler.Lower.Types (nativeValueType, typeFactAt, typeForSpan)
import Pudu.Core
import Pudu.Compiler.Lower.Dynamic (mapRuntimeChoice, projectRuntimeValue)
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| A call to a function of any module: its signature is admitted under that
    module's facts, then the arguments run here, in the caller's. -}
lowerFunctionCall :: LowerExpression -> LowerState -> Span -> Text -> Span -> [Located Expression] -> Lowered
lowerFunctionCall lower state at key callee arguments = case lookup key (contextTable (lowerContext state)) of
  Nothing -> halt at "this call" state
  Just entry ->
    case admitCalleeGiven state (traverse (typeFactAt (contextTypes (lowerContext state)) . locatedSpan) arguments) key callee entry of
        (back, Nothing) -> refused back
        (back, Just (target, found))
          | not (null (signatureLoaned found)) ->
              lowerLoanedCall lower back at target found (takesSuppliedCount found) arguments
        (back, Just (target, found)) -> case collect back [] arguments of
          (final, Just given) ->
            let expected = parameterKinds found <> repeat CoreNeverType
                (ready, carried) = mapAccumL carry final (zip expected given)
             in passing entry ready target found carried
          (final, Nothing) -> refused final
 where
  passing entry final target found cores
    | any ((== CoreNeverType) . coreExpressionType) cores =
        typed final (CoreBlockValue (CoreBlock
          [CoreStatement (coreExpressionSpan argument) (CoreEvaluate argument) | argument <- cores] Nothing)) CoreNeverType
    | Just (copied, copy, signature) <- runtimeCallSignature entry final target found (map coreExpressionType cores) =
        let (projected, carried) = mapAccumL carry copied (zip (parameterKinds signature) cores)
         in call projected copy signature carried
    | otherwise = call final target found cores
  call current target signature cores =
    let queued = queue target current
        passed
          | takesSuppliedCount signature = suppliedArguments at (parameterKinds signature) cores
          | otherwise = cores
     in typed queued (CoreCall target passed) (eagerType (signatureResult signature) cores)
  carry current (expected, core) = projectRuntimeValue (contextTypes (lowerContext current)) current expected core
  parameterKinds = map (coreLocalType . coreParameterLocal) . signatureParameters

  typed after shape kind = (after, Just (CoreExpression at kind shape, kind))
  queue target current = current{lowerContext = (lowerContext current){contextQueue = target : contextQueue (lowerContext current)}}
  collect current done [] = (current, Just (reverse done))
  collect current done (argument : rest) = case lower current argument of
    (after, Just (core, _))
      | coreExpressionType core == CoreNeverType -> (after, Just (reverse (core : done)))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | otherwise -> collect after (core : done) rest
    (after, Nothing) -> (after, Nothing)

{-| Standard-stream output keeps its checked Result. The internal write
    outcome is bound once before either variant is constructed. -}
lowerPrint :: LowerExpression -> LowerState -> Span -> Text -> [Located Expression] -> Lowered
lowerPrint lower state at name arguments = case arguments of
  [argument] -> case lower state argument of
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, kind)) | nativeValueType kind, not (expressionIsPrintValued core) ->
      case typeForSpan (contextTypes (lowerContext after)) at of
        Just result@(CoreSumType "Result" [CoreUnitType, CoreTextType]) ->
          let (ready, text) = outputText at after core
           in outputResult ready at name text result
        _ -> halt at "output without a represented Result[(), Str] type" after
    (after, Just (_, kind)) -> halt at ("printing a " <> coreTypeName kind <> " value") after
    (after, Nothing) -> refused after
  _ -> halt at ("a call to " <> name <> " with this many arguments") state

outputText :: Span -> LowerState -> CoreExpression -> (LowerState, CoreExpression)
outputText at state core
  | coreExpressionType core == CoreTextType = (state, core)
  | Just (ready, Just (rendered, _)) <- mapRuntimeChoice state at CoreTextType core render =
      (ready, rendered)
  | otherwise = (state, CoreExpression at CoreTextType (CoreShow core))
 where
  render current held =
    let (ready, rendered) = outputText at current held
     in (ready, Just rendered)

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
