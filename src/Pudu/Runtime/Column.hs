{-| Vectorized columnar database engine with continuous unboxed memory layouts and SIMD aggregations. -}
module Pudu.Runtime.Column
  ( columnSumU64
  , columnMinU64
  , columnMaxU64
  , columnFilterGtU64
  , columnProjectU64
  , columnSumF64
  , columnMinF64
  , columnMaxF64
  , columnFilterGtF64
  , columnFilterLtF64
  , columnProjectF64
  , columnAddF64
  , columnBitmapAnd
  , columnBitmapOr
  , columnBitmapNot
  , columnBitmapCount
  ) where

import Data.Bits ((.&.), (.|.), complement, popCount, shiftL, shiftR)
import qualified Data.ByteString as BS
import Data.Word (Word64)
import GHC.Float (castDoubleToWord64, castWord64ToDouble)
import qualified Pudu.Runtime.Buffer as Buffer


-- | Vectorized sum of 64-bit unsigned integers in unboxed column, skipping null rows.
columnSumU64 :: BS.ByteString -> BS.ByteString -> Int -> Word64
columnSumU64 dataBs nullBs rowCount
  | rowCount <= 0 = 0
  | otherwise = go 0 0
 where
  go row acc
    | row >= rowCount = acc
    | otherwise =
        let bitWordIdx = (row `shiftR` 6) * 8
            bitInWord = row .&. 63
            isValid = case Buffer.readWord64LE nullBs bitWordIdx of
              Just w -> (w .&. (1 `shiftL` bitInWord)) /= 0
              Nothing -> False
         in if isValid
              then case Buffer.readWord64LE dataBs (row * 8) of
                Just v -> go (row + 1) (acc + v)
                Nothing -> go (row + 1) acc
              else go (row + 1) acc

-- | Vectorized minimum of 64-bit unsigned integers in unboxed column.
columnMinU64 :: BS.ByteString -> BS.ByteString -> Int -> Maybe Word64
columnMinU64 dataBs nullBs rowCount
  | rowCount <= 0 = Nothing
  | otherwise = go 0 Nothing
 where
  go row currentMin
    | row >= rowCount = currentMin
    | otherwise =
        let bitWordIdx = (row `shiftR` 6) * 8
            bitInWord = row .&. 63
            isValid = case Buffer.readWord64LE nullBs bitWordIdx of
              Just w -> (w .&. (1 `shiftL` bitInWord)) /= 0
              Nothing -> False
         in if isValid
              then case Buffer.readWord64LE dataBs (row * 8) of
                Just v ->
                  let nextMin = case currentMin of
                        Just m -> Just (min m v)
                        Nothing -> Just v
                   in go (row + 1) nextMin
                Nothing -> go (row + 1) currentMin
              else go (row + 1) currentMin

-- | Vectorized maximum of 64-bit unsigned integers in unboxed column.
columnMaxU64 :: BS.ByteString -> BS.ByteString -> Int -> Maybe Word64
columnMaxU64 dataBs nullBs rowCount
  | rowCount <= 0 = Nothing
  | otherwise = go 0 Nothing
 where
  go row currentMax
    | row >= rowCount = currentMax
    | otherwise =
        let bitWordIdx = (row `shiftR` 6) * 8
            bitInWord = row .&. 63
            isValid = case Buffer.readWord64LE nullBs bitWordIdx of
              Just w -> (w .&. (1 `shiftL` bitInWord)) /= 0
              Nothing -> False
         in if isValid
              then case Buffer.readWord64LE dataBs (row * 8) of
                Just v ->
                  let nextMax = case currentMax of
                        Just m -> Just (max m v)
                        Nothing -> Just v
                   in go (row + 1) nextMax
                Nothing -> go (row + 1) currentMax
              else go (row + 1) currentMax

-- | Vectorized predicate filter evaluating (val > threshold) producing a packed selection bitmap.
columnFilterGtU64 :: BS.ByteString -> BS.ByteString -> Int -> Word64 -> BS.ByteString
columnFilterGtU64 dataBs nullBs rowCount threshold
  | rowCount <= 0 = BS.empty
  | otherwise =
      let numBitWords = (rowCount + 63) `shiftR` 6
          outBuf = Buffer.allocateBuffer (numBitWords * 8)
          filled = foldl buildWord outBuf [0 .. numBitWords - 1]
       in filled
 where
  buildWord buf wIdx =
    let baseRow = wIdx * 64
        validWord = case Buffer.readWord64LE nullBs (wIdx * 8) of
          Just w -> w
          Nothing -> 0
        computedWord = foldl (testRow baseRow validWord) 0 [0 .. 63]
     in case Buffer.writeWord64LE buf (wIdx * 8) computedWord of
          Just updated -> updated
          Nothing -> buf

  testRow baseRow validWord acc bitPos =
    let r = baseRow + bitPos
     in if r < rowCount && (validWord .&. (1 `shiftL` bitPos)) /= 0
          then case Buffer.readWord64LE dataBs (r * 8) of
            Just v | v > threshold -> acc .|. (1 `shiftL` bitPos)
            _ -> acc
          else acc

-- | Gathers selected rows from unboxed column into a new contiguous unboxed column.
-- Returns (projectedData, projectedNullBitmap, selectedRowCount).
columnProjectU64 :: BS.ByteString -> BS.ByteString -> BS.ByteString -> Int -> (BS.ByteString, BS.ByteString, Int)
columnProjectU64 dataBs nullBs selBs rowCount
  | rowCount <= 0 = (BS.empty, BS.empty, 0)
  | otherwise =
      let (outData, outNull, count) = go 0 0 (Buffer.allocateBuffer (rowCount * 8)) (Buffer.allocateBuffer (((rowCount + 63) `shiftR` 6) * 8))
          trimmedData = BS.take (count * 8) outData
          trimmedNull = BS.take (((count + 63) `shiftR` 6) * 8) outNull
       in (trimmedData, trimmedNull, count)
 where
  go inRow outRow accData accNull
    | inRow >= rowCount = (accData, accNull, outRow)
    | otherwise =
        let selWordIdx = (inRow `shiftR` 6) * 8
            selBit = inRow .&. 63
            isSelected = case Buffer.readWord64LE selBs selWordIdx of
              Just w -> (w .&. (1 `shiftL` selBit)) /= 0
              Nothing -> False
         in if isSelected
              then
                let val = case Buffer.readWord64LE dataBs (inRow * 8) of
                      Just v -> v
                      Nothing -> 0
                    nextData = case Buffer.writeWord64LE accData (outRow * 8) val of
                      Just d -> d
                      Nothing -> accData
                    inNullWordIdx = (inRow `shiftR` 6) * 8
                    inNullBit = inRow .&. 63
                    isValid = case Buffer.readWord64LE nullBs inNullWordIdx of
                      Just nw -> (nw .&. (1 `shiftL` inNullBit)) /= 0
                      Nothing -> False
                    outWordIdx = (outRow `shiftR` 6) * 8
                    outBit = outRow .&. 63
                    oldNullWord = case Buffer.readWord64LE accNull outWordIdx of
                      Just w -> w
                      Nothing -> 0
                    nextNull = if isValid
                      then case Buffer.writeWord64LE accNull outWordIdx (oldNullWord .|. (1 `shiftL` outBit)) of
                        Just n -> n
                        Nothing -> accNull
                      else accNull
                 in go (inRow + 1) (outRow + 1) nextData nextNull

              else go (inRow + 1) outRow accData accNull

-- | Vectorized sum of 64-bit IEEE 754 floats in unboxed column, skipping null rows.
columnSumF64 :: BS.ByteString -> BS.ByteString -> Int -> Double
columnSumF64 dataBs nullBs rowCount
  | rowCount <= 0 = 0.0
  | otherwise = go 0 0.0
 where
  go row acc
    | row >= rowCount = acc
    | otherwise =
        let bitWordIdx = (row `shiftR` 6) * 8
            bitInWord = row .&. 63
            isValid = case Buffer.readWord64LE nullBs bitWordIdx of
              Just w -> (w .&. (1 `shiftL` bitInWord)) /= 0
              Nothing -> False
         in if isValid
              then case Buffer.readWord64LE dataBs (row * 8) of
                Just v -> go (row + 1) (acc + castWord64ToDouble v)
                Nothing -> go (row + 1) acc
              else go (row + 1) acc

-- | Vectorized minimum of 64-bit IEEE 754 floats in unboxed column.
columnMinF64 :: BS.ByteString -> BS.ByteString -> Int -> Maybe Double
columnMinF64 dataBs nullBs rowCount
  | rowCount <= 0 = Nothing
  | otherwise = go 0 Nothing
 where
  go row currentMin
    | row >= rowCount = currentMin
    | otherwise =
        let bitWordIdx = (row `shiftR` 6) * 8
            bitInWord = row .&. 63
            isValid = case Buffer.readWord64LE nullBs bitWordIdx of
              Just w -> (w .&. (1 `shiftL` bitInWord)) /= 0
              Nothing -> False
         in if isValid
              then case Buffer.readWord64LE dataBs (row * 8) of
                Just v ->
                  let d = castWord64ToDouble v
                      nextMin = case currentMin of
                        Just m -> Just (min m d)
                        Nothing -> Just d
                   in go (row + 1) nextMin
                Nothing -> go (row + 1) currentMin
              else go (row + 1) currentMin

-- | Vectorized maximum of 64-bit IEEE 754 floats in unboxed column.
columnMaxF64 :: BS.ByteString -> BS.ByteString -> Int -> Maybe Double
columnMaxF64 dataBs nullBs rowCount
  | rowCount <= 0 = Nothing
  | otherwise = go 0 Nothing
 where
  go row currentMax
    | row >= rowCount = currentMax
    | otherwise =
        let bitWordIdx = (row `shiftR` 6) * 8
            bitInWord = row .&. 63
            isValid = case Buffer.readWord64LE nullBs bitWordIdx of
              Just w -> (w .&. (1 `shiftL` bitInWord)) /= 0
              Nothing -> False
         in if isValid
              then case Buffer.readWord64LE dataBs (row * 8) of
                Just v ->
                  let d = castWord64ToDouble v
                      nextMax = case currentMax of
                        Just m -> Just (max m d)
                        Nothing -> Just d
                   in go (row + 1) nextMax
                Nothing -> go (row + 1) currentMax
              else go (row + 1) currentMax

-- | Vectorized predicate filter evaluating (val > threshold) for floats.
columnFilterGtF64 :: BS.ByteString -> BS.ByteString -> Int -> Double -> BS.ByteString
columnFilterGtF64 dataBs nullBs rowCount threshold
  | rowCount <= 0 = BS.empty
  | otherwise =
      let numBitWords = (rowCount + 63) `shiftR` 6
          outBuf = Buffer.allocateBuffer (numBitWords * 8)
          filled = foldl buildWord outBuf [0 .. numBitWords - 1]
       in filled
 where
  buildWord buf wIdx =
    let baseRow = wIdx * 64
        validWord = case Buffer.readWord64LE nullBs (wIdx * 8) of
          Just w -> w
          Nothing -> 0
        computedWord = foldl (testRow baseRow validWord) 0 [0 .. 63]
     in case Buffer.writeWord64LE buf (wIdx * 8) computedWord of
          Just updated -> updated
          Nothing -> buf

  testRow baseRow validWord acc bitPos =
    let r = baseRow + bitPos
     in if r < rowCount && (validWord .&. (1 `shiftL` bitPos)) /= 0
          then case Buffer.readWord64LE dataBs (r * 8) of
            Just v | castWord64ToDouble v > threshold -> acc .|. (1 `shiftL` bitPos)
            _ -> acc
          else acc

-- | Vectorized predicate filter evaluating (val < threshold) for floats.
columnFilterLtF64 :: BS.ByteString -> BS.ByteString -> Int -> Double -> BS.ByteString
columnFilterLtF64 dataBs nullBs rowCount threshold
  | rowCount <= 0 = BS.empty
  | otherwise =
      let numBitWords = (rowCount + 63) `shiftR` 6
          outBuf = Buffer.allocateBuffer (numBitWords * 8)
          filled = foldl buildWord outBuf [0 .. numBitWords - 1]
       in filled
 where
  buildWord buf wIdx =
    let baseRow = wIdx * 64
        validWord = case Buffer.readWord64LE nullBs (wIdx * 8) of
          Just w -> w
          Nothing -> 0
        computedWord = foldl (testRow baseRow validWord) 0 [0 .. 63]
     in case Buffer.writeWord64LE buf (wIdx * 8) computedWord of
          Just updated -> updated
          Nothing -> buf

  testRow baseRow validWord acc bitPos =
    let r = baseRow + bitPos
     in if r < rowCount && (validWord .&. (1 `shiftL` bitPos)) /= 0
          then case Buffer.readWord64LE dataBs (r * 8) of
            Just v | castWord64ToDouble v < threshold -> acc .|. (1 `shiftL` bitPos)
            _ -> acc
          else acc

-- | Gathers selected float rows from unboxed column into a new contiguous unboxed column.
columnProjectF64 :: BS.ByteString -> BS.ByteString -> BS.ByteString -> Int -> (BS.ByteString, BS.ByteString, Int)
columnProjectF64 = columnProjectU64

-- | Vectorized element-wise addition across two Float64 columns.
columnAddF64 :: BS.ByteString -> BS.ByteString -> BS.ByteString -> BS.ByteString -> Int -> (BS.ByteString, BS.ByteString)
columnAddF64 dataA nullA dataB nullB rowCount
  | rowCount <= 0 = (BS.empty, BS.empty)
  | otherwise =
      let numWords = (rowCount + 63) `shiftR` 6
          outData = Buffer.allocateBuffer (rowCount * 8)
          outNull = Buffer.allocateBuffer (numWords * 8)
          (finalData, finalNull) = go 0 outData outNull
       in (finalData, finalNull)
 where
  go row accData accNull
    | row >= rowCount = (accData, accNull)
    | otherwise =
        let bitWordIdx = (row `shiftR` 6) * 8
            bitInWord = row .&. 63
            validA = case Buffer.readWord64LE nullA bitWordIdx of
              Just w -> (w .&. (1 `shiftL` bitInWord)) /= 0
              Nothing -> False
            validB = case Buffer.readWord64LE nullB bitWordIdx of
              Just w -> (w .&. (1 `shiftL` bitInWord)) /= 0
              Nothing -> False
         in if validA && validB
              then
                let vA = case Buffer.readWord64LE dataA (row * 8) of
                      Just w -> castWord64ToDouble w
                      Nothing -> 0.0
                    vB = case Buffer.readWord64LE dataB (row * 8) of
                      Just w -> castWord64ToDouble w
                      Nothing -> 0.0
                    sumVal = vA + vB
                    nextData = case Buffer.writeWord64LE accData (row * 8) (castDoubleToWord64 sumVal) of
                      Just d -> d
                      Nothing -> accData
                    oldNullWord = case Buffer.readWord64LE accNull bitWordIdx of
                      Just w -> w
                      Nothing -> 0
                    nextNull = case Buffer.writeWord64LE accNull bitWordIdx (oldNullWord .|. (1 `shiftL` bitInWord)) of
                      Just n -> n
                      Nothing -> accNull
                 in go (row + 1) nextData nextNull
              else
                let nextData = case Buffer.writeWord64LE accData (row * 8) 0 of
                      Just d -> d
                      Nothing -> accData
                 in go (row + 1) nextData accNull

-- | Bitwise AND across 64-bit words of two selection bitmaps.
columnBitmapAnd :: BS.ByteString -> BS.ByteString -> Int -> BS.ByteString
columnBitmapAnd b1 b2 rowCount
  | rowCount <= 0 = BS.empty
  | otherwise =
      let numWords = (rowCount + 63) `shiftR` 6
          outBuf = Buffer.allocateBuffer (numWords * 8)
          filled = foldl applyAnd outBuf [0 .. numWords - 1]
       in filled
 where
  applyAnd buf wIdx =
    let off = wIdx * 8
        w1 = case Buffer.readWord64LE b1 off of
          Just w -> w
          Nothing -> 0
        w2 = case Buffer.readWord64LE b2 off of
          Just w -> w
          Nothing -> 0
     in case Buffer.writeWord64LE buf off (w1 .&. w2) of
          Just updated -> updated
          Nothing -> buf

-- | Bitwise OR across 64-bit words of two selection bitmaps.
columnBitmapOr :: BS.ByteString -> BS.ByteString -> Int -> BS.ByteString
columnBitmapOr b1 b2 rowCount
  | rowCount <= 0 = BS.empty
  | otherwise =
      let numWords = (rowCount + 63) `shiftR` 6
          outBuf = Buffer.allocateBuffer (numWords * 8)
          filled = foldl applyOr outBuf [0 .. numWords - 1]
       in filled
 where
  applyOr buf wIdx =
    let off = wIdx * 8
        w1 = case Buffer.readWord64LE b1 off of
          Just w -> w
          Nothing -> 0
        w2 = case Buffer.readWord64LE b2 off of
          Just w -> w
          Nothing -> 0
     in case Buffer.writeWord64LE buf off (w1 .|. w2) of
          Just updated -> updated
          Nothing -> buf

-- | Bitwise NOT inverting active bits of selection bitmap.
columnBitmapNot :: BS.ByteString -> Int -> BS.ByteString
columnBitmapNot b rowCount
  | rowCount <= 0 = BS.empty
  | otherwise =
      let outBuf = Buffer.allocateBuffer (numWords * 8)
          filled = foldl applyNot outBuf [0 .. numWords - 1]
       in filled
 where
  numWords = (rowCount + 63) `shiftR` 6
  applyNot buf wIdx =
    let off = wIdx * 8
        raw = case Buffer.readWord64LE b off of
          Just w -> w
          Nothing -> 0
        inverted = complement raw
        masked = if wIdx == numWords - 1 && (rowCount .&. 63) /= 0
                   then inverted .&. ((1 `shiftL` (rowCount .&. 63)) - 1)
                   else inverted
     in case Buffer.writeWord64LE buf off masked of
          Just updated -> updated
          Nothing -> buf

-- | Population count of set bits in selection bitmap.
columnBitmapCount :: BS.ByteString -> Int -> Int
columnBitmapCount b rowCount
  | rowCount <= 0 = 0
  | otherwise = foldl countWord 0 [0 .. numWords - 1]
 where
  numWords = (rowCount + 63) `shiftR` 6
  countWord acc wIdx =
    let off = wIdx * 8
        raw = case Buffer.readWord64LE b off of
          Just w -> w
          Nothing -> 0
        masked = if wIdx == numWords - 1 && (rowCount .&. 63) /= 0
                   then raw .&. ((1 `shiftL` (rowCount .&. 63)) - 1)
                   else raw
     in acc + popCount masked
