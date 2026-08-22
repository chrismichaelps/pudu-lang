{-| @Eval.Operator.Module — applies operator and access semantics -}
module Pudu.Eval.Operator
  ( applyUnary
  , combine
  , readIndex
  , readMember
  , unwrapTry
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..), valueKind)
import Pudu.Source (Span)

applyUnary :: Span -> Text -> Value -> Evaluator Value
applyUnary spanValue operator value = case (operator, value) of
  ("-", IntValue number) -> pure (IntValue (negate number))
  ("-", FloatValue number) -> pure (FloatValue (negate number))
  ("!", BoolValue flag) -> pure (BoolValue (not flag))
  ("&", _) -> pure value
  ("&mut", _) -> pure value
  _ ->
    abortAt (Just spanValue) "E7001"
      ("cannot apply " <> operator <> " to a " <> valueKind value) Nothing

combine :: Span -> Text -> Value -> Value -> Evaluator Value
combine spanValue operator left right = case (left, right) of
  (IntValue a, IntValue b) -> integerOperation spanValue operator a b
  (FloatValue a, FloatValue b) -> floatOperation spanValue operator a b
  (StrValue a, StrValue b) -> textOperation spanValue operator a b
  (CharValue a, CharValue b) -> comparisonOnly spanValue operator a b
  (BoolValue a, BoolValue b) -> comparisonOnly spanValue operator a b
  _ | operator == "==" -> pure (BoolValue (left == right))
    | operator == "!=" -> pure (BoolValue (left /= right))
  _ ->
    abortAt (Just spanValue) "E7001"
      ("cannot apply " <> operator <> " to a " <> valueKind left <> " and a " <> valueKind right)
      Nothing

integerOperation :: Span -> Text -> Integer -> Integer -> Evaluator Value
integerOperation spanValue operator left right = case operator of
  "+" -> pure (IntValue (left + right))
  "-" -> pure (IntValue (left - right))
  "*" -> pure (IntValue (left * right))
  "&+" -> pure (IntValue (left + right))
  "&-" -> pure (IntValue (left - right))
  "&*" -> pure (IntValue (left * right))
  "+|" -> pure (IntValue (left + right))
  "-|" -> pure (IntValue (left - right))
  "*|" -> pure (IntValue (left * right))
  "/" ->
    if right == 0
      then abortAt (Just spanValue) "E7004" "division by zero" Nothing
      else pure (IntValue (quot left right))
  "%" ->
    if right == 0
      then abortAt (Just spanValue) "E7004" "division by zero" Nothing
      else pure (IntValue (rem left right))
  ".." -> pure (TupleValue (map IntValue [left .. right - 1]))
  "..=" -> pure (TupleValue (map IntValue [left .. right]))
  _ -> comparisonOnly spanValue operator left right

floatOperation :: Span -> Text -> Double -> Double -> Evaluator Value
floatOperation spanValue operator left right = case operator of
  "+" -> pure (FloatValue (left + right))
  "-" -> pure (FloatValue (left - right))
  "*" -> pure (FloatValue (left * right))
  "/" -> pure (FloatValue (left / right))
  _ -> comparisonOnly spanValue operator left right

textOperation :: Span -> Text -> Text -> Text -> Evaluator Value
textOperation spanValue operator left right = case operator of
  "+" -> pure (StrValue (left <> right))
  _ -> comparisonOnly spanValue operator left right

comparisonOnly :: Ord a => Span -> Text -> a -> a -> Evaluator Value
comparisonOnly spanValue operator left right = case operator of
  "==" -> pure (BoolValue (left == right))
  "!=" -> pure (BoolValue (left /= right))
  "<" -> pure (BoolValue (left < right))
  "<=" -> pure (BoolValue (left <= right))
  ">" -> pure (BoolValue (left > right))
  ">=" -> pure (BoolValue (left >= right))
  _ -> abortAt (Just spanValue) "E7001" ("unsupported operator " <> operator) Nothing

readIndex :: Span -> Value -> Value -> Evaluator Value
readIndex spanValue container key = case (container, key) of
  (TupleValue members, IntValue index)
    | index >= 0 && fromInteger index < length members -> pure (members !! fromInteger index)
    | otherwise -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
  (StrValue text, IntValue index)
    | index >= 0 && fromInteger index < Text.length text ->
        pure (CharValue (Text.index text (fromInteger index)))
    | otherwise -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
  _ ->
    abortAt (Just spanValue) "E7001"
      ("cannot index a " <> valueKind container) Nothing

readMember :: Span -> Value -> Text -> Evaluator Value
readMember spanValue value member = case value of
  RecordValue _ fields -> case lookup member fields of
    Just found -> pure found
    Nothing -> abortAt (Just spanValue) "E7001" ("no field " <> member) Nothing
  VariantValue name _ | name == member -> pure value
  _ ->
    abortAt (Just spanValue) "E7001"
      ("cannot read " <> member <> " from a " <> valueKind value) Nothing

unwrapTry :: Span -> Value -> Evaluator Value
unwrapTry spanValue value = case value of
  VariantValue "Ok" [inner] -> pure inner
  VariantValue "Err" _ -> pure value
  _ -> abortAt (Just spanValue) "E7001" "? expects a Result value" Nothing
