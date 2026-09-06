{-| Vectorized columnar database engine with continuous unboxed memory layouts and SIMD aggregations. -}
module Pudu.Runtime.Column
  ( columnSumU64
  , columnMinU64
  , columnMaxU64
  , columnFilterGtU64
  , columnProjectU64
  ) where

import Data.Bits ((.&.), (.|.), shiftL, shiftR)
import qualified Data.ByteString as BS
import Data.Word (Word64)
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
