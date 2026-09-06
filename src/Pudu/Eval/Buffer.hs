{-| Builtin evaluators for low-level contiguous byte buffers. -}
module Pudu.Eval.Buffer
  ( callBufferAlloc
  , callBufferReadU64
  , callBufferWriteU64
  , callBufferScanU64
  , callBufferCopy
  , callBufferSize
  ) where

import Data.Word (Word64)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..), intOf)
import Pudu.IntegerLiteral (IntegerKind (UnsignedKind))
import qualified Pudu.Runtime.Buffer as Buffer
import Pudu.Source (Span)

someValue :: Value -> Value
someValue v = VariantValue "Some" [v]

noneValue :: Value
noneValue = VariantValue "None" []

callBufferAlloc :: Span -> [Value] -> Evaluator Value
callBufferAlloc spanValue arguments = case arguments of
  [IntValue _ n]
    | n < 0 -> abortAt (Just spanValue) "E7004" "buffer allocation size cannot be negative" Nothing
    | otherwise -> pure (BytesValue (Buffer.allocateBuffer (fromIntegral n)))
  [_] -> abortAt (Just spanValue) "E7001" "bufferAlloc expects an integer size" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferAlloc expects one argument" Nothing

callBufferReadU64 :: Span -> [Value] -> Evaluator Value
callBufferReadU64 spanValue arguments = case arguments of
  [BytesValue bs, IntValue _ offset] ->
    case Buffer.readWord64LE bs (fromIntegral offset) of
      Just w -> pure (someValue (IntValue (UnsignedKind 64) (toInteger w)))
      Nothing -> pure noneValue
  [_, _] -> abortAt (Just spanValue) "E7001" "bufferReadU64 expects a buffer and integer offset" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferReadU64 expects two arguments" Nothing

callBufferWriteU64 :: Span -> [Value] -> Evaluator Value
callBufferWriteU64 spanValue arguments = case arguments of
  [BytesValue bs, IntValue _ offset, IntValue _ val]
    | val >= 0 && val <= toInteger (maxBound :: Word64) ->
        case Buffer.writeWord64LE bs (fromIntegral offset) (fromIntegral val) of
          Just updated -> pure (someValue (BytesValue updated))
          Nothing -> pure noneValue
    | otherwise ->
        abortAt (Just spanValue) "E7004" "bufferWriteU64 value outside UInt64 range" Nothing
  [_, _, _] -> abortAt (Just spanValue) "E7001" "bufferWriteU64 expects buffer, offset, and UInt64" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferWriteU64 expects three arguments" Nothing

callBufferScanU64 :: Span -> [Value] -> Evaluator Value
callBufferScanU64 spanValue arguments = case arguments of
  [BytesValue bs, IntValue _ offset, IntValue _ count, IntValue _ needle]
    | needle >= 0 && needle <= toInteger (maxBound :: Word64) ->
        case Buffer.scanWord64 bs (fromIntegral offset) (fromIntegral count) (fromIntegral needle) of
          Just idx -> pure (someValue (intOf (fromIntegral idx)))
          Nothing -> pure noneValue
    | otherwise -> pure noneValue
  [_, _, _, _] -> abortAt (Just spanValue) "E7001" "bufferScanU64 expects buffer, offset, count, and needle" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferScanU64 expects four arguments" Nothing

callBufferCopy :: Span -> [Value] -> Evaluator Value
callBufferCopy spanValue arguments = case arguments of
  [BytesValue src, IntValue _ srcOff, BytesValue dst, IntValue _ dstOff, IntValue _ len] ->
    case Buffer.copyBytes src (fromIntegral srcOff) dst (fromIntegral dstOff) (fromIntegral len) of
      Just updated -> pure (someValue (BytesValue updated))
      Nothing -> pure noneValue
  [_, _, _, _, _] -> abortAt (Just spanValue) "E7001" "bufferCopy expects src, srcOff, dst, dstOff, len" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferCopy expects five arguments" Nothing

callBufferSize :: Span -> [Value] -> Evaluator Value
callBufferSize spanValue arguments = case arguments of
  [BytesValue bs] -> pure (intOf (fromIntegral (Buffer.bufferSize bs)))
  [_] -> abortAt (Just spanValue) "E7001" "bufferSize expects a buffer" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferSize expects one argument" Nothing
