{-| @Runtime.Column.Index — vectorized permutation indexing, sorting, binary search, and gather operations -}
module Pudu.Runtime.Column.Index
  ( isRowValid
  , columnSortIndicesU64
  , columnSortIndicesF64
  , columnBinarySearchU64
  , columnBinarySearchF64
  , columnGatherU64
  , columnGatherF64
  ) where

import Data.Bits ((.&.), (.|.), shiftL, shiftR)
import qualified Data.ByteString as BS
import Data.List (partition, sortBy)
import Data.Ord (comparing)
import Data.Word (Word64)
import GHC.Float (castWord64ToDouble)
import qualified Pudu.Runtime.Buffer as Buffer

-- | Tests if a given row is valid (non-null) in the null bitmap.
isRowValid :: BS.ByteString -> Int -> Bool
isRowValid nullBs row =
  let bitWordIdx = (row `shiftR` 6) * 8
      bitInWord = row .&. 63
   in case Buffer.readWord64LE nullBs bitWordIdx of
        Just w -> (w .&. (1 `shiftL` bitInWord)) /= 0
        Nothing -> False

-- | Produces a packed permutation index buffer containing row offsets sorted in ascending order (NULLS LAST).
columnSortIndicesU64 :: BS.ByteString -> BS.ByteString -> Int -> BS.ByteString
columnSortIndicesU64 dataBs nullBs rowCount
  | rowCount <= 0 = BS.empty
  | otherwise =
      let (validRows, nullRows) = partition (isRowValid nullBs) [0 .. rowCount - 1]
          getVal r = case Buffer.readWord64LE dataBs (r * 8) of
            Just w -> w
            Nothing -> 0
          sortedValid = sortBy (comparing getVal) validRows
          allSorted = sortedValid ++ nullRows
          outBuf = Buffer.allocateBuffer (rowCount * 8)
          writeIdx (buf, off) r =
            case Buffer.writeWord64LE buf off (fromIntegral r) of
              Just updated -> (updated, off + 8)
              Nothing -> (buf, off + 8)
          (finalBuf, _) = foldl writeIdx (outBuf, 0) allSorted
       in finalBuf

-- | Produces a packed permutation index buffer for float rows sorted in ascending order (NULLS LAST).
columnSortIndicesF64 :: BS.ByteString -> BS.ByteString -> Int -> BS.ByteString
columnSortIndicesF64 dataBs nullBs rowCount
  | rowCount <= 0 = BS.empty
  | otherwise =
      let (validRows, nullRows) = partition (isRowValid nullBs) [0 .. rowCount - 1]
          getVal r = case Buffer.readWord64LE dataBs (r * 8) of
            Just w -> castWord64ToDouble w
            Nothing -> 0.0
          sortedValid = sortBy (comparing getVal) validRows
          allSorted = sortedValid ++ nullRows
          outBuf = Buffer.allocateBuffer (rowCount * 8)
          writeIdx (buf, off) r =
            case Buffer.writeWord64LE buf off (fromIntegral r) of
              Just updated -> (updated, off + 8)
              Nothing -> (buf, off + 8)
          (finalBuf, _) = foldl writeIdx (outBuf, 0) allSorted
       in finalBuf

-- | Performs O(log N) binary search over valid portion of sorted permutation index.
columnBinarySearchU64 :: BS.ByteString -> BS.ByteString -> Int -> Word64 -> Maybe Int
columnBinarySearchU64 dataBs permBs validCount target
  | validCount <= 0 = Nothing
  | otherwise = go 0 (validCount - 1)
 where
  go low high
    | low > high = Nothing
    | otherwise =
        let mid = (low + high) `shiftR` 1
         in case Buffer.readWord64LE permBs (mid * 8) of
              Nothing -> Nothing
              Just row ->
                case Buffer.readWord64LE dataBs (fromIntegral row * 8) of
                  Nothing -> Nothing
                  Just val -> case compare val target of
                    EQ -> Just (fromIntegral row)
                    LT -> go (mid + 1) high
                    GT -> go low (mid - 1)

-- | Performs O(log N) binary search over valid portion of float sorted permutation index.
columnBinarySearchF64 :: BS.ByteString -> BS.ByteString -> Int -> Double -> Maybe Int
columnBinarySearchF64 dataBs permBs validCount target
  | validCount <= 0 = Nothing
  | otherwise = go 0 (validCount - 1)
 where
  go low high
    | low > high = Nothing
    | otherwise =
        let mid = (low + high) `shiftR` 1
         in case Buffer.readWord64LE permBs (mid * 8) of
              Nothing -> Nothing
              Just row ->
                case Buffer.readWord64LE dataBs (fromIntegral row * 8) of
                  Nothing -> Nothing
                  Just w ->
                    let val = castWord64ToDouble w
                     in case compare val target of
                          EQ -> Just (fromIntegral row)
                          LT -> go (mid + 1) high
                          GT -> go low (mid - 1)

-- | Gathers row elements according to a permutation index buffer into a new unboxed column.
columnGatherU64 :: BS.ByteString -> BS.ByteString -> BS.ByteString -> Int -> (BS.ByteString, BS.ByteString, Int)
columnGatherU64 dataBs nullBs permBs permCount
  | permCount <= 0 = (BS.empty, BS.empty, 0)
  | otherwise =
      let numBitWords = (permCount + 63) `shiftR` 6
          destData0 = Buffer.allocateBuffer (permCount * 8)
          destNull0 = Buffer.allocateBuffer (numBitWords * 8)
          (finalData, finalNull) = foldl gatherRow (destData0, destNull0) [0 .. permCount - 1]
       in (finalData, finalNull, permCount)
 where
  gatherRow (dBuf, nBuf) dstIdx =
    case Buffer.readWord64LE permBs (dstIdx * 8) of
      Nothing -> (dBuf, nBuf)
      Just srcRowWord ->
        let srcRow = fromIntegral srcRowWord
            bitWordIdx = (dstIdx `shiftR` 6) * 8
            bitInWord = dstIdx .&. 63
         in if isRowValid nullBs srcRow
              then
                let val = case Buffer.readWord64LE dataBs (srcRow * 8) of
                      Just w -> w
                      Nothing -> 0
                    curNullWord = case Buffer.readWord64LE nBuf bitWordIdx of
                      Just w -> w
                      Nothing -> 0
                    dBuf' = case Buffer.writeWord64LE dBuf (dstIdx * 8) val of
                      Just updated -> updated
                      Nothing -> dBuf
                    nBuf' = case Buffer.writeWord64LE nBuf bitWordIdx (curNullWord .|. (1 `shiftL` bitInWord)) of
                      Just updated -> updated
                      Nothing -> nBuf
                 in (dBuf', nBuf')
              else
                let dBuf' = case Buffer.writeWord64LE dBuf (dstIdx * 8) 0 of
                      Just updated -> updated
                      Nothing -> dBuf
                 in (dBuf', nBuf)

-- | Gathers float row elements according to a permutation index buffer into a new unboxed column.
columnGatherF64 :: BS.ByteString -> BS.ByteString -> BS.ByteString -> Int -> (BS.ByteString, BS.ByteString, Int)
columnGatherF64 = columnGatherU64
