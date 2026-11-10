{-| @Compiler.Lower.Store — the indexed store's builder, `hashOf`, `mixHash`
    and the MultiMap pair, as direct calls and as callable bodies. -}
module Pudu.Compiler.Lower.Store (lowerStorePrimitive, storeCallable, storePrimitive) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Array (stopped)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Keyed (Blame (..))
import Pudu.Compiler.Lower.MultiMap (multiMapBody)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), halt, intType, refused)
import Pudu.Compiler.Lower.Types (nativeValueType, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

storePrimitive :: Text -> Bool
storePrimitive name = name `elem` ["bucketsOf", "hashOf", "mixHash", "multiMapAdd", "multiMapContains"]

{-| A direct call: operands run once in source order, and one that never
    returns ends the call before later operands run. -}
lowerStorePrimitive :: (LowerState -> Located Expression -> Lowered)
  -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerStorePrimitive lower state at name arguments
  | storePrimitive name = Just (go state [] arguments)
  | otherwise = Nothing
 where
  go current done [] = case typeForSpan (contextTypes (lowerContext current)) at of
    Just result
      | let cores = reverse done
      , Just build <- storeCallable AtCall name (CoreFunctionType (map coreExpressionType cores) result) -> build current at cores
    _ -> halt at ("a call to " <> name <> " without its represented signature") current
  go current done (argument : rest) = case lower current argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (stopped at (reverse (core : done)), CoreNeverType))
    (after, Just (core, _)) -> go after (core : done) rest

{-| The body for an exact signature, over operands already in hand. The blame
    says where a refusal inside points: the call, or the call made through a
    value of the builtin. -}
storeCallable :: Blame -> Text -> CoreType -> Maybe (LowerState -> Span -> [CoreExpression] -> Lowered)
storeCallable blame name signature = case (name, signature) of
  -- An empty store is the store built from no pairs.
  ("bucketsOf", CoreFunctionType [] kind@(CoreStoreType held)) -> Just $ \state at _ ->
    let pairs = CoreExpression at (CoreArrayType (CoreTupleType [intType, held])) (CoreArray [])
     in (state, Just (CoreExpression at kind (CoreKeyedMethod KeyedFromArray pairs []), kind))
  ("mixHash", CoreFunctionType [operand] result) | operand == intType, result == intType -> Just $ \state at arguments ->
    case arguments of
      [value] -> (state, Just (CoreExpression at intType (CoreKeyedMethod KeyedMixHash value []), intType))
      _ -> halt at "a mixHash call without its operand" state
  -- Text, bytes and integers hash by their own bytes; anything else by the
  -- text it shows as.
  ("hashOf", CoreFunctionType [operand] result) | result == intType, nativeValueType operand -> Just $ \state at arguments ->
    case arguments of
      [value]
        | expressionIsPrintValued value -> halt at "hashOf of a Result[(), Str] value" state
        | otherwise ->
            let hashed = case operand of
                  CoreTextType -> value
                  CoreBytesType -> value
                  CoreIntegerType _ -> value
                  _ -> CoreExpression at CoreTextType (CoreShow value)
             in (state, Just (CoreExpression at intType (CoreKeyedMethod KeyedHash hashed []), intType))
      _ -> halt at "a hashOf call without its operand" state
  (_, CoreFunctionType [_, _, _] _) | name `elem` ["multiMapAdd", "multiMapContains"] ->
    Just (multiMapBody blame name signature)
  _ -> Nothing
