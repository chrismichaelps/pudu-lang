{-| @Program.Eval.Builtin.Array — array method dispatch and higher-order callbacks -}
module Pudu.Eval.Builtin.Array
  ( Apply
  , callArrayMethod
  ) where

import Control.Monad (foldM)
import qualified Data.Sequence as Seq
import qualified Data.Text as Text

import Pudu.Eval.Array
  ( arrayConcat
  , arrayContains
  , arrayIndex
  , arrayIndexOf
  , arrayInsert
  , arrayLength
  , arrayPop
  , arrayPush
  , arrayRemove
  , arrayReverse
  , arraySlice
  , arrayToList
  )
import Pudu.Eval.Env (Evaluator (..), abortAt)
import Pudu.Eval.Value (ArrayMethod (..), Value (..), intOf)
import Pudu.Source (Span)

type Apply = Span -> Value -> [Value] -> Evaluator Value

acceptByFunction :: Apply -> Span -> Value -> Value -> Evaluator Bool
acceptByFunction apply spanValue function element = do
  result <- apply spanValue function [element]
  case result of
    BoolValue flag -> pure flag
    _ -> abortAt (Just spanValue) "E7001" "filter predicate must return Bool" Nothing

{-| Apply a built-in array method. Each method has fixed arity and semantics
    defined in [[Eval Array]]. -}
callArrayMethod :: Apply -> Span -> ArrayMethod -> Value -> [Value] -> Evaluator Value
callArrayMethod apply spanValue method receiver arguments = case method of
  ArrayLength -> case arguments of
    [] -> case arrayLength receiver of
      Just len -> pure (intOf (fromIntegral len))
      Nothing -> abortAt (Just spanValue) "E7001" "not an array" Nothing
    _ -> wrongArity "length" 0
  ArrayIsEmpty -> case arguments of
    [] -> case arrayLength receiver of
      Just len -> pure (BoolValue (len == 0))
      Nothing -> abortAt (Just spanValue) "E7001" "not an array" Nothing
    _ -> wrongArity "isEmpty" 0
  ArrayGet -> case arguments of
    [IntValue _ index] -> case arrayIndex receiver (fromInteger index) of
      Just value -> pure value
      Nothing -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
    _ -> wrongArity "get" 1
  ArrayIndexOf -> case arguments of
    [target] -> pure (intOf (fromIntegral (arrayIndexOf receiver target)))
    _ -> wrongArity "indexOf" 1
  ArrayContains -> case arguments of
    [target] -> pure (BoolValue (arrayContains receiver target))
    _ -> wrongArity "contains" 1
  ArrayPush -> case arguments of
    [value] -> pure (arrayPush receiver value)
    _ -> wrongArity "push" 1
  ArrayPop -> case arguments of
    [] -> pure (arrayPop receiver)
    _ -> wrongArity "pop" 0
  ArrayInsert -> case arguments of
    [IntValue _ index, value] -> pure (arrayInsert receiver (fromInteger index) value)
    _ -> wrongArity "insert" 2
  ArrayRemove -> case arguments of
    [IntValue _ index] -> pure (arrayRemove receiver (fromInteger index))
    _ -> wrongArity "remove" 1
  ArraySlice -> case arguments of
    [IntValue _ start, IntValue _ end'] -> pure (arraySlice receiver (fromInteger start) (fromInteger end'))
    _ -> wrongArity "slice" 2
  ArrayConcat -> case arguments of
    [other@(ArrayValue _)] -> pure (arrayConcat receiver other)
    [_] -> abortAt (Just spanValue) "E7001" "concat expects an array" Nothing
    _ -> wrongArity "concat" 1
  ArrayJoin -> case arguments of
    [StrValue separator] -> case arrayToList receiver of
      Just values -> do
        pieces <- mapM asText values
        pure (StrValue (Text.intercalate separator pieces))
      Nothing -> abortAt (Just spanValue) "E7001" "not an array" Nothing
    [_] -> abortAt (Just spanValue) "E7001" "join expects text" Nothing
    _ -> wrongArity "join" 1
   where
    asText value = case value of
      StrValue held -> pure held
      _ -> abortAt (Just spanValue) "E7001" "join expects an array of text" Nothing
  ArrayReverse -> case arguments of
    [] -> pure (arrayReverse receiver)
    _ -> wrongArity "reverse" 0
  ArrayMap -> case arguments of
    [closureValue] -> case receiver of
      ArrayValue elements ->
        ArrayValue <$> traverse (apply spanValue closureValue . (: [])) elements
      _ -> abortAt (Just spanValue) "E7001" "not an array" Nothing
    _ -> wrongArity "map" 1
  ArrayFilter -> case arguments of
    [closureValue] -> case receiver of
      ArrayValue elements -> do
        kept <- foldM (keepAccepted closureValue) Seq.empty elements
        pure (ArrayValue kept)
      _ -> abortAt (Just spanValue) "E7001" "not an array" Nothing
    _ -> wrongArity "filter" 1
  ArrayReduce -> case arguments of
    [closureValue, initial] -> case receiver of
      ArrayValue elements ->
        foldM (\acc element -> apply spanValue closureValue [acc, element]) initial elements
      _ -> abortAt (Just spanValue) "E7001" "not an array" Nothing
    _ -> wrongArity "reduce" 2
 where
  keepAccepted closureValue kept element = do
    accepted <- acceptByFunction apply spanValue closureValue element
    let next = if accepted then kept Seq.|> element else kept
    next `seq` pure next

  wrongArity name expected =
    abortAt (Just spanValue) "E7003"
      (Text.pack (name <> " expects " <> show (expected :: Int) <> " argument(s)"))
      (Just "check the method's argument count")
