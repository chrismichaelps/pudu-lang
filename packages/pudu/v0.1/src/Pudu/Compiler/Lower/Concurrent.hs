{-| @Compiler.Lower.Concurrent — the host builtins whose signature holds a
    type parameter: cells, channel items and the function a thread runs, as
    direct calls and as callable bodies. A held value crosses as a box of one
    member, so the runtime stores every type the same way. -}
module Pudu.Compiler.Lower.Concurrent (lowerConcurrentPrimitive, concurrentCallable, concurrentPrimitive) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Array (stopped)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (nativeValueType, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

concurrentPrimitive :: Text -> Bool
concurrentPrimitive name =
  name `elem` ["cellOpen", "cellGet", "cellSwap", "channelPush", "channelPull", "channelPullWithin", "spawnThread"]

{-| A direct call: operands run once in source order, and one that never
    returns ends the call before later operands run. -}
lowerConcurrentPrimitive :: (LowerState -> Located Expression -> Lowered)
  -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerConcurrentPrimitive lower state at name arguments
  | concurrentPrimitive name = Just (go state [] arguments)
  | otherwise = Nothing
 where
  go current done [] = case typeForSpan (contextTypes (lowerContext current)) at of
    Just result
      | let cores = reverse done
      , Just build <- concurrentCallable name (CoreFunctionType (map coreExpressionType cores) result) -> build current at cores
    _ -> halt at ("a call to " <> name <> " without its represented signature") current
  go current done (argument : rest) = case lower current argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (stopped at (reverse (core : done)), CoreNeverType))
    (after, Just (core, _))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | otherwise -> go after (core : done) rest

{-| The body for an exact signature, over operands already in hand. -}
concurrentCallable :: Text -> CoreType -> Maybe (LowerState -> Span -> [CoreExpression] -> Lowered)
concurrentCallable name signature = case (name, signature) of
  ("cellOpen", CoreFunctionType [held] result) | result == intType, nativeValueType held -> Just $ \state at operands ->
    case operands of
      [value] -> (state, Just (CoreExpression at intType (CoreKernel (KernelHost "cell_open") [] [boxed at held value]), intType))
      _ -> halt at "a cellOpen call without its operand" state
  ("cellGet", CoreFunctionType [token] result@(CoreSumType "Result" [held, CoreTextType]))
    | token == intType, nativeValueType held -> Just $ \state at operands ->
        answered state at result held "cell_get" operands (\found _ -> ok at result found)
  ("cellSwap", CoreFunctionType [token, given] result@(CoreSumType "Result" [held, CoreTextType]))
    | token == intType, given == held, nativeValueType held -> Just $ \state at operands -> case operands of
        [place, value] -> answered state at result held "cell_swap" [place, boxed at held value] (\found _ -> ok at result found)
        _ -> halt at "a cellSwap call without its operands" state
  ("channelPush", CoreFunctionType [token, held] result@(CoreSumType "Result" [CoreUnitType, CoreTextType]))
    | token == intType, nativeValueType held -> Just $ \state at operands -> case operands of
        [place, value] ->
          let (after, local) = bindLocal state "" CoreBoolType
              sent = CoreExpression at CoreBoolType (CoreKernel (KernelHost "channel_push") [] [place, boxed at held value])
              unit = CoreExpression at CoreUnitType (CoreBlockValue (CoreBlock [] Nothing))
           in finished after at result [CoreStatement at (CoreDeclare local sent)] (ok at result unit)
        _ -> halt at "a channelPush call without its operands" state
  ("channelPull", CoreFunctionType [token] result@(CoreSumType "Result" [inner@(CoreSumType "Option" [held]), CoreTextType]))
    | token == intType, nativeValueType held -> Just $ \state at operands ->
        answered state at result held "channel_pull" operands (\found level -> ok at result (present at inner (level 2) found))
  ("channelPullWithin", CoreFunctionType [token, wait] result@(CoreSumType "Result" [outer@(CoreSumType "Option" [inner@(CoreSumType "Option" [held])]), CoreTextType]))
    | token == intType, wait == intType, nativeValueType held -> Just $ \state at operands ->
        answered state at result held "channel_pull_within" operands
          (\found level -> ok at result (present at outer (level 2) (present at inner (level 3) found)))
  ("spawnThread", CoreFunctionType [CoreFunctionType [] CoreUnitType] result@(CoreSumType "Result" [token, CoreTextType]))
    | token == intType -> Just $ \state at operands ->
        (state, Just (ok at result (CoreExpression at intType (CoreKernel (KernelHost "thread_spawn") [] operands)), result))
  _ -> Nothing

{-| A value as the box of one member the runtime holds. -}
boxed :: Span -> CoreType -> CoreExpression -> CoreExpression
boxed at held value = CoreExpression at (CoreTupleType [held]) (CoreTuple [value])

ok :: Span -> CoreType -> CoreExpression -> CoreExpression
ok at result found = CoreExpression at result (CoreConstruct "Ok" [("0", found)])

{-| None when the test holds, else Some of the value. -}
present :: Span -> CoreType -> CoreExpression -> CoreExpression -> CoreExpression
present at kind absent found = CoreExpression at kind (CoreIfValue absent
  (CoreBlock [] (Just (CoreExpression at kind (CoreConstruct "None" [])))) (CoreExpression at kind (CoreConstruct "Some" [("0", found)])))

{-| A kernel answering a held value's box: the box is bound once, then the
    host's state picks the failure or what the box holds. -}
answered :: LowerState -> Span -> CoreType -> CoreType -> Text -> [CoreExpression]
  -> (CoreExpression -> (Integer -> CoreExpression) -> CoreExpression) -> Lowered
answered state at result held name operands build =
  let carrier = CoreTupleType [held]
      (after, local) = bindLocal state "" carrier
      box = CoreExpression at carrier (CoreReadLocal local)
      found = CoreExpression at held (CoreTupleIndex 0 box)
      run = CoreStatement at (CoreDeclare local (CoreExpression at carrier (CoreKernel (KernelHost name) [] operands)))
   in finished after at result [run] (build found (stateIs at))

{-| The failure when the host refused, else the value. -}
finished :: LowerState -> Span -> CoreType -> [CoreStatement] -> CoreExpression -> Lowered
finished state at result statements value =
  let failure = CoreExpression at result (CoreConstruct "Err" [("0", CoreExpression at CoreTextType (CoreKernel KernelHostMessage [] []))])
      chosen = CoreExpression at result (CoreIfValue (stateIs at 1) (CoreBlock [] (Just failure)) value)
   in (state, Just (CoreExpression at result (CoreBlockValue (CoreBlock statements (Just chosen))), result))

stateIs :: Span -> Integer -> CoreExpression
stateIs at level = CoreExpression at CoreBoolType (CoreBinary CoreEqual
  (CoreExpression at intType (CoreKernel KernelHostState [] []))
  (CoreExpression at intType (CoreIntegerLiteral PlatformSigned level)))
