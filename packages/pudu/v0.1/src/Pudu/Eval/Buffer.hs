{-| Builtin evaluators for low-level contiguous byte buffers. -}
module Pudu.Eval.Buffer
  ( callBufferAlloc
  , callBufferReadU64
  , callBufferWriteU64
  , callBufferReadI64
  , callBufferWriteI64
  , callBufferReadF64
  , callBufferWriteF64
  , callBufferReadU32
  , callBufferWriteU32
  , callBufferFill
  , callBufferCompare
  , callBufferScanU64
  , callBufferCopy
  , callBufferSize
  ) where

import Data.Int (Int64)
import Data.Word (Word32, Word64)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..), intOf)
import Pudu.FloatLiteral (FloatWidth (Float64Width))
import Pudu.IntegerLiteral (IntegerKind (SignedKind, UnsignedKind))
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

callBufferReadI64 :: Span -> [Value] -> Evaluator Value
callBufferReadI64 spanValue arguments = case arguments of
  [BytesValue bs, IntValue _ offset] ->
    case Buffer.readInt64LE bs (fromIntegral offset) of
      Just w -> pure (someValue (IntValue (SignedKind 64) (toInteger w)))
      Nothing -> pure noneValue
  [_, _] -> abortAt (Just spanValue) "E7001" "bufferReadI64 expects a buffer and integer offset" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferReadI64 expects two arguments" Nothing

callBufferWriteI64 :: Span -> [Value] -> Evaluator Value
callBufferWriteI64 spanValue arguments = case arguments of
  [BytesValue bs, IntValue _ offset, IntValue _ val]
    | val >= toInteger (minBound :: Int64) && val <= toInteger (maxBound :: Int64) ->
        case Buffer.writeInt64LE bs (fromIntegral offset) (fromIntegral val) of
          Just updated -> pure (someValue (BytesValue updated))
          Nothing -> pure noneValue
    | otherwise ->
        abortAt (Just spanValue) "E7004" "bufferWriteI64 value outside Int64 range" Nothing
  [_, _, _] -> abortAt (Just spanValue) "E7001" "bufferWriteI64 expects buffer, offset, and Int64" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferWriteI64 expects three arguments" Nothing

callBufferReadF64 :: Span -> [Value] -> Evaluator Value
callBufferReadF64 spanValue arguments = case arguments of
  [BytesValue bs, IntValue _ offset] ->
    case Buffer.readFloat64LE bs (fromIntegral offset) of
      Just d -> pure (someValue (FloatValue Float64Width d))
      Nothing -> pure noneValue
  [_, _] -> abortAt (Just spanValue) "E7001" "bufferReadF64 expects a buffer and integer offset" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferReadF64 expects two arguments" Nothing

callBufferWriteF64 :: Span -> [Value] -> Evaluator Value
callBufferWriteF64 spanValue arguments = case arguments of
  [BytesValue bs, IntValue _ offset, FloatValue _ d] ->
    case Buffer.writeFloat64LE bs (fromIntegral offset) d of
      Just updated -> pure (someValue (BytesValue updated))
      Nothing -> pure noneValue
  [_, _, _] -> abortAt (Just spanValue) "E7001" "bufferWriteF64 expects buffer, offset, and Float64" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferWriteF64 expects three arguments" Nothing

callBufferReadU32 :: Span -> [Value] -> Evaluator Value
callBufferReadU32 spanValue arguments = case arguments of
  [BytesValue bs, IntValue _ offset] ->
    case Buffer.readWord32LE bs (fromIntegral offset) of
      Just w -> pure (someValue (IntValue (UnsignedKind 32) (toInteger w)))
      Nothing -> pure noneValue
  [_, _] -> abortAt (Just spanValue) "E7001" "bufferReadU32 expects a buffer and integer offset" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferReadU32 expects two arguments" Nothing

callBufferWriteU32 :: Span -> [Value] -> Evaluator Value
callBufferWriteU32 spanValue arguments = case arguments of
  [BytesValue bs, IntValue _ offset, IntValue _ val]
    | val >= 0 && val <= toInteger (maxBound :: Word32) ->
        case Buffer.writeWord32LE bs (fromIntegral offset) (fromIntegral val) of
          Just updated -> pure (someValue (BytesValue updated))
          Nothing -> pure noneValue
    | otherwise ->
        abortAt (Just spanValue) "E7004" "bufferWriteU32 value outside UInt32 range" Nothing
  [_, _, _] -> abortAt (Just spanValue) "E7001" "bufferWriteU32 expects buffer, offset, and UInt32" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferWriteU32 expects three arguments" Nothing

callBufferFill :: Span -> [Value] -> Evaluator Value
callBufferFill spanValue arguments = case arguments of
  [BytesValue bs, IntValue _ offset, IntValue _ len, IntValue _ b]
    | b >= 0 && b <= 255 ->
        case Buffer.fillBytes bs (fromIntegral offset) (fromIntegral len) (fromIntegral b) of
          Just updated -> pure (someValue (BytesValue updated))
          Nothing -> pure noneValue
    | otherwise ->
        abortAt (Just spanValue) "E7004" "bufferFill byte value outside UInt8 range" Nothing
  [_, _, _, _] -> abortAt (Just spanValue) "E7001" "bufferFill expects buffer, offset, len, and byte" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferFill expects four arguments" Nothing

callBufferCompare :: Span -> [Value] -> Evaluator Value
callBufferCompare spanValue arguments = case arguments of
  [BytesValue bs1, IntValue _ off1, BytesValue bs2, IntValue _ off2, IntValue _ len] ->
    case Buffer.compareBytes bs1 (fromIntegral off1) bs2 (fromIntegral off2) (fromIntegral len) of
      Just cmp -> pure (someValue (intOf (fromIntegral cmp)))
      Nothing -> pure noneValue
  [_, _, _, _, _] -> abortAt (Just spanValue) "E7001" "bufferCompare expects b1, off1, b2, off2, len" Nothing
  _ -> abortAt (Just spanValue) "E7003" "bufferCompare expects five arguments" Nothing

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
