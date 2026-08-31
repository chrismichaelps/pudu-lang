{-| @Eval.Order.Module — which runtime values may be keys -}
module Pudu.Eval.Order
  ( OrdValue (..)
  , comparableValue
  , compareValues
  ) where

import Data.Foldable (toList)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Pudu.Eval.Value (OrdValue (..), Value (..), compareValues)

{-| Whether a value can be a key.

    A function, a task, and a partially applied built-in method cannot: two of
    them are equal only when their syntax is, and no ordering of them means
    anything to a reader. Everything a program can compare with `<` can be a
    key, and so can the aggregates built out of those.

    The order itself lives with `Value`, because the keyed collections are
    constructors of that type and cannot be declared without it. This module
    keeps the separate question of which values the order may be *asked* about,
    which is the one the evaluator puts before every insertion. -}
comparableValue :: Value -> Bool
comparableValue value = case value of
  FunctionValue _ -> False
  TaskValue{} -> False
  BuiltinValue _ -> False
  ArrayMethodValue _ _ -> False
  StringMethodValue _ _ -> False
  CharMethodValue _ _ -> False
  MapValue entries ->
    all (\(key, held) -> comparableValue (unOrdValue key) && comparableValue held) (Map.toAscList entries)
  SetValue members -> all (comparableValue . unOrdValue) (Set.toAscList members)
  TupleValue members -> all comparableValue members
  ArrayValue members -> all comparableValue (toList members)
  RecordValue _ fields -> all (comparableValue . snd) fields
  VariantValue _ payload -> all comparableValue payload
  _ -> True
