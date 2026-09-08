{-| Builtin evaluators for vectorized columnar database operations. -}
module Pudu.Eval.Column
  ( callColumnSumU64
  , callColumnMinU64
  , callColumnMaxU64
  , callColumnFilterGtU64
  , callColumnProjectU64
  , callColumnSumF64
  , callColumnMinF64
  , callColumnMaxF64
  , callColumnFilterGtF64
  , callColumnFilterLtF64
  , callColumnProjectF64
  , callColumnAddF64
  , callColumnBitmapAnd
  , callColumnBitmapOr
  , callColumnBitmapNot
  , callColumnBitmapCount
  , callColumnSortIndicesU64
  , callColumnSortIndicesF64
  , callColumnBinarySearchU64
  , callColumnBinarySearchF64
  , callColumnGatherU64
  , callColumnGatherF64
  ) where

import Data.Word (Word64)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..), intOf)
import Pudu.FloatLiteral (FloatWidth (Float64Width))
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

callColumnSumF64 :: Span -> [Value] -> Evaluator Value
callColumnSumF64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, IntValue _ rowCount] ->
    let res = Column.columnSumF64 dataBs nullBs (fromIntegral rowCount)
     in pure (FloatValue Float64Width res)
  [_, _, _] -> abortAt (Just spanValue) "E7001" "columnSumF64 expects data buffer, null bitmap, and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnSumF64 expects three arguments" Nothing

callColumnMinF64 :: Span -> [Value] -> Evaluator Value
callColumnMinF64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, IntValue _ rowCount] ->
    case Column.columnMinF64 dataBs nullBs (fromIntegral rowCount) of
      Just m -> pure (someValue (FloatValue Float64Width m))
      Nothing -> pure noneValue
  [_, _, _] -> abortAt (Just spanValue) "E7001" "columnMinF64 expects data buffer, null bitmap, and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnMinF64 expects three arguments" Nothing

callColumnMaxF64 :: Span -> [Value] -> Evaluator Value
callColumnMaxF64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, IntValue _ rowCount] ->
    case Column.columnMaxF64 dataBs nullBs (fromIntegral rowCount) of
      Just m -> pure (someValue (FloatValue Float64Width m))
      Nothing -> pure noneValue
  [_, _, _] -> abortAt (Just spanValue) "E7001" "columnMaxF64 expects data buffer, null bitmap, and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnMaxF64 expects three arguments" Nothing

callColumnFilterGtF64 :: Span -> [Value] -> Evaluator Value
callColumnFilterGtF64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, IntValue _ rowCount, FloatValue _ threshold] ->
    let sel = Column.columnFilterGtF64 dataBs nullBs (fromIntegral rowCount) threshold
     in pure (BytesValue sel)
  [_, _, _, _] -> abortAt (Just spanValue) "E7001" "columnFilterGtF64 expects data, null bitmap, row count, and threshold" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnFilterGtF64 expects four arguments" Nothing

callColumnFilterLtF64 :: Span -> [Value] -> Evaluator Value
callColumnFilterLtF64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, IntValue _ rowCount, FloatValue _ threshold] ->
    let sel = Column.columnFilterLtF64 dataBs nullBs (fromIntegral rowCount) threshold
     in pure (BytesValue sel)
  [_, _, _, _] -> abortAt (Just spanValue) "E7001" "columnFilterLtF64 expects data, null bitmap, row count, and threshold" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnFilterLtF64 expects four arguments" Nothing

callColumnProjectF64 :: Span -> [Value] -> Evaluator Value
callColumnProjectF64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, BytesValue selBs, IntValue _ rowCount] ->
    let (pData, pNull, pCount) = Column.columnProjectF64 dataBs nullBs selBs (fromIntegral rowCount)
     in pure (TupleValue [BytesValue pData, BytesValue pNull, intOf (fromIntegral pCount)])
  [_, _, _, _] -> abortAt (Just spanValue) "E7001" "columnProjectF64 expects data, null bitmap, selection mask, and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnProjectF64 expects four arguments" Nothing

callColumnAddF64 :: Span -> [Value] -> Evaluator Value
callColumnAddF64 spanValue arguments = case arguments of
  [BytesValue dataA, BytesValue nullA, BytesValue dataB, BytesValue nullB, IntValue _ rowCount] ->
    let (resData, resNull) = Column.columnAddF64 dataA nullA dataB nullB (fromIntegral rowCount)
     in pure (TupleValue [BytesValue resData, BytesValue resNull])
  [_, _, _, _, _] -> abortAt (Just spanValue) "E7001" "columnAddF64 expects two data buffers, two null bitmaps, and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnAddF64 expects five arguments" Nothing

callColumnBitmapAnd :: Span -> [Value] -> Evaluator Value
callColumnBitmapAnd spanValue arguments = case arguments of
  [BytesValue b1, BytesValue b2, IntValue _ rowCount] ->
    let res = Column.columnBitmapAnd b1 b2 (fromIntegral rowCount)
     in pure (BytesValue res)
  [_, _, _] -> abortAt (Just spanValue) "E7001" "columnBitmapAnd expects two selection bitmaps and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnBitmapAnd expects three arguments" Nothing

callColumnBitmapOr :: Span -> [Value] -> Evaluator Value
callColumnBitmapOr spanValue arguments = case arguments of
  [BytesValue b1, BytesValue b2, IntValue _ rowCount] ->
    let res = Column.columnBitmapOr b1 b2 (fromIntegral rowCount)
     in pure (BytesValue res)
  [_, _, _] -> abortAt (Just spanValue) "E7001" "columnBitmapOr expects two selection bitmaps and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnBitmapOr expects three arguments" Nothing

callColumnBitmapNot :: Span -> [Value] -> Evaluator Value
callColumnBitmapNot spanValue arguments = case arguments of
  [BytesValue b, IntValue _ rowCount] ->
    let res = Column.columnBitmapNot b (fromIntegral rowCount)
     in pure (BytesValue res)
  [_, _] -> abortAt (Just spanValue) "E7001" "columnBitmapNot expects selection bitmap and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnBitmapNot expects two arguments" Nothing

callColumnBitmapCount :: Span -> [Value] -> Evaluator Value
callColumnBitmapCount spanValue arguments = case arguments of
  [BytesValue b, IntValue _ rowCount] ->
    let count = Column.columnBitmapCount b (fromIntegral rowCount)
     in pure (intOf (fromIntegral count))
  [_, _] -> abortAt (Just spanValue) "E7001" "columnBitmapCount expects selection bitmap and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnBitmapCount expects two arguments" Nothing

callColumnSortIndicesU64 :: Span -> [Value] -> Evaluator Value
callColumnSortIndicesU64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, IntValue _ rowCount] ->
    let res = Column.columnSortIndicesU64 dataBs nullBs (fromIntegral rowCount)
     in pure (BytesValue res)
  [_, _, _] -> abortAt (Just spanValue) "E7001" "columnSortIndicesU64 expects data buffer, null bitmap, and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnSortIndicesU64 expects three arguments" Nothing

callColumnSortIndicesF64 :: Span -> [Value] -> Evaluator Value
callColumnSortIndicesF64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, IntValue _ rowCount] ->
    let res = Column.columnSortIndicesF64 dataBs nullBs (fromIntegral rowCount)
     in pure (BytesValue res)
  [_, _, _] -> abortAt (Just spanValue) "E7001" "columnSortIndicesF64 expects data buffer, null bitmap, and row count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnSortIndicesF64 expects three arguments" Nothing

callColumnBinarySearchU64 :: Span -> [Value] -> Evaluator Value
callColumnBinarySearchU64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue permBs, IntValue _ validCount, IntValue _ target]
    | target >= 0 && target <= toInteger (maxBound :: Word64) ->
        case Column.columnBinarySearchU64 dataBs permBs (fromIntegral validCount) (fromIntegral target) of
          Just r -> pure (someValue (intOf (fromIntegral r)))
          Nothing -> pure noneValue
    | otherwise ->
        abortAt (Just spanValue) "E7004" "columnBinarySearchU64 target outside UInt64 range" Nothing
  [_, _, _, _] -> abortAt (Just spanValue) "E7001" "columnBinarySearchU64 expects data buffer, index buffer, count, and target" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnBinarySearchU64 expects four arguments" Nothing

callColumnBinarySearchF64 :: Span -> [Value] -> Evaluator Value
callColumnBinarySearchF64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue permBs, IntValue _ validCount, FloatValue _ target] ->
    case Column.columnBinarySearchF64 dataBs permBs (fromIntegral validCount) target of
      Just r -> pure (someValue (intOf (fromIntegral r)))
      Nothing -> pure noneValue
  [_, _, _, _] -> abortAt (Just spanValue) "E7001" "columnBinarySearchF64 expects data buffer, index buffer, count, and target" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnBinarySearchF64 expects four arguments" Nothing

callColumnGatherU64 :: Span -> [Value] -> Evaluator Value
callColumnGatherU64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, BytesValue permBs, IntValue _ permCount] ->
    let (gData, gNull, gCount) = Column.columnGatherU64 dataBs nullBs permBs (fromIntegral permCount)
     in pure (TupleValue [BytesValue gData, BytesValue gNull, intOf (fromIntegral gCount)])
  [_, _, _, _] -> abortAt (Just spanValue) "E7001" "columnGatherU64 expects data buffer, null bitmap, index buffer, and count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnGatherU64 expects four arguments" Nothing

callColumnGatherF64 :: Span -> [Value] -> Evaluator Value
callColumnGatherF64 spanValue arguments = case arguments of
  [BytesValue dataBs, BytesValue nullBs, BytesValue permBs, IntValue _ permCount] ->
    let (gData, gNull, gCount) = Column.columnGatherF64 dataBs nullBs permBs (fromIntegral permCount)
     in pure (TupleValue [BytesValue gData, BytesValue gNull, intOf (fromIntegral gCount)])
  [_, _, _, _] -> abortAt (Just spanValue) "E7001" "columnGatherF64 expects data buffer, null bitmap, index buffer, and count" Nothing
  _ -> abortAt (Just spanValue) "E7003" "columnGatherF64 expects four arguments" Nothing
