{-| Builtin evaluators for vectorized columnar database operations. -}
module Pudu.Eval.Column
  ( callColumnSumU64
  , callColumnMinU64
  , callColumnMaxU64
  , callColumnFilterGtU64
  , callColumnProjectU64
  ) where

import Data.Word (Word64)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..), intOf)
import Pudu.IntegerLiteral (IntegerKind (UnsignedKind))
import qualified Pudu.Runtime.Column as Column
import Pudu.Source (Span)

someValue :: Value -> Value
someValue v = VariantValue "Some" [v]

noneValue :: Value
noneValue = VariantValue "None" []

callColumnSumU64 :: Span -> [Value] -> Evaluator Value
callColumnSumU64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, IntValue _ rowCount] ->
    let res = Column.columnSumU64 dataBs nullBs (fromIntegral rowCount)
     in pure (IntValue (UnsignedKind 64) (toInteger res))
  [_, _, _] -> abortAt (Just spanValue) "E7001" "columnSumU64 expects data buffer, null bitmap, and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnSumU64 expects three arguments" Nothing

callColumnMinU64 :: Span -> [Value] -> Evaluator Value
callColumnMinU64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, IntValue _ rowCount] ->
    case Column.columnMinU64 dataBs nullBs (fromIntegral rowCount) of
      Just m -> pure (someValue (IntValue (UnsignedKind 64) (toInteger m)))
      Nothing -> pure noneValue
  [_, _, _] -> abortAt (Just spanValue) "E7001" "columnMinU64 expects data buffer, null bitmap, and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnMinU64 expects three arguments" Nothing

callColumnMaxU64 :: Span -> [Value] -> Evaluator Value
callColumnMaxU64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, IntValue _ rowCount] ->
    case Column.columnMaxU64 dataBs nullBs (fromIntegral rowCount) of
      Just m -> pure (someValue (IntValue (UnsignedKind 64) (toInteger m)))
      Nothing -> pure noneValue
  [_, _, _] -> abortAt (Just spanValue) "E7001" "columnMaxU64 expects data buffer, null bitmap, and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnMaxU64 expects three arguments" Nothing

callColumnFilterGtU64 :: Span -> [Value] -> Evaluator Value
callColumnFilterGtU64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, IntValue _ rowCount, IntValue _ threshold]
    | threshold >= 0 && threshold <= toInteger (maxBound :: Word64) ->
        let sel = Column.columnFilterGtU64 dataBs nullBs (fromIntegral rowCount) (fromIntegral threshold)
         in pure (BytesValue sel)
    | otherwise ->
        abortAt (Just spanValue) "E7004" "columnFilterGtU64 threshold outside UInt64 range" Nothing
  [_, _, _, _] -> abortAt (Just spanValue) "E7001" "columnFilterGtU64 expects data, null bitmap, row count, and threshold" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnFilterGtU64 expects four arguments" Nothing

callColumnProjectU64 :: Span -> [Value] -> Evaluator Value
callColumnProjectU64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, BytesValue selBs, IntValue _ rowCount] ->
    let (pData, pNull, pCount) = Column.columnProjectU64 dataBs nullBs selBs (fromIntegral rowCount)
     in pure (TupleValue [BytesValue pData, BytesValue pNull, intOf (fromIntegral pCount)])
  [_, _, _, _] -> abortAt (Just spanValue) "E7001" "columnProjectU64 expects data, null bitmap, selection mask, and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnProjectU64 expects four arguments" Nothing
