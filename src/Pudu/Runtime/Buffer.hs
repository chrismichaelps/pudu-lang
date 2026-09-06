{-| Low-level unboxed contiguous byte buffer operations, independent of evaluator values. -}
module Pudu.Runtime.Buffer
  ( allocateBuffer
  , bufferSize
  , readWord64LE
  , writeWord64LE
  , readInt64LE
  , writeInt64LE
  , readFloat64LE
  , writeFloat64LE
  , readWord32LE
  , writeWord32LE
  , fillBytes
  , compareBytes
  , copyBytes
  , scanWord64
  ) where

import Data.Bits ((.&.), (.|.), shiftL, shiftR)
import qualified Data.ByteString as BS
import Data.Int (Int64)
import Data.Word (Word8, Word32, Word64)
import GHC.Float (castDoubleToWord64, castWord64ToDouble)

{-| Allocate a zero-initialized contiguous byte buffer of length N. -}
allocateBuffer :: Int -> BS.ByteString
allocateBuffer n
  | n <= 0 = BS.empty
  | otherwise = BS.replicate n 0

{-| The byte length of a buffer. -}
bufferSize :: BS.ByteString -> Int
bufferSize = BS.length

{-| Read an unsigned 64-bit word at a byte offset in little-endian byte order. -}
readWord64LE :: BS.ByteString -> Int -> Maybe Word64
readWord64LE bs offset
  | offset < 0 || offset + 8 > BS.length bs = Nothing
  | otherwise =
      let b0 = fromIntegral (BS.index bs offset)
          b1 = fromIntegral (BS.index bs (offset + 1))
          b2 = fromIntegral (BS.index bs (offset + 2))
          b3 = fromIntegral (BS.index bs (offset + 3))
          b4 = fromIntegral (BS.index bs (offset + 4))
          b5 = fromIntegral (BS.index bs (offset + 5))
          b6 = fromIntegral (BS.index bs (offset + 6))
          b7 = fromIntegral (BS.index bs (offset + 7))
       in Just
            ( b0
                .|. (b1 `shiftL` 8)
                .|. (b2 `shiftL` 16)
                .|. (b3 `shiftL` 24)
                .|. (b4 `shiftL` 32)
                .|. (b5 `shiftL` 40)
                .|. (b6 `shiftL` 48)
                .|. (b7 `shiftL` 56)
            )

{-| Write an unsigned 64-bit word at a byte offset in little-endian byte order. -}
writeWord64LE :: BS.ByteString -> Int -> Word64 -> Maybe BS.ByteString
writeWord64LE bs offset val
  | offset < 0 || offset + 8 > BS.length bs = Nothing
  | otherwise =
      let (before, rest) = BS.splitAt offset bs
          after = BS.drop 8 rest
          bytes =
            BS.pack
              [ fromIntegral (val .&. 0xFF)
              , fromIntegral ((val `shiftR` 8) .&. 0xFF)
              , fromIntegral ((val `shiftR` 16) .&. 0xFF)
              , fromIntegral ((val `shiftR` 24) .&. 0xFF)
              , fromIntegral ((val `shiftR` 32) .&. 0xFF)
              , fromIntegral ((val `shiftR` 40) .&. 0xFF)
              , fromIntegral ((val `shiftR` 48) .&. 0xFF)
              , fromIntegral ((val `shiftR` 56) .&. 0xFF)
              ]
       in Just (BS.concat [before, bytes, after])

{-| Read a signed 64-bit integer at a byte offset in little-endian order. -}
readInt64LE :: BS.ByteString -> Int -> Maybe Int64
readInt64LE bs offset = fromIntegral <$> readWord64LE bs offset

{-| Write a signed 64-bit integer at a byte offset in little-endian order. -}
writeInt64LE :: BS.ByteString -> Int -> Int64 -> Maybe BS.ByteString
writeInt64LE bs offset val = writeWord64LE bs offset (fromIntegral val)

{-| Read an IEEE-754 64-bit floating point number at a byte offset via hardware register bit-cast. -}
readFloat64LE :: BS.ByteString -> Int -> Maybe Double
readFloat64LE bs offset = castWord64ToDouble <$> readWord64LE bs offset

{-| Write an IEEE-754 64-bit floating point number at a byte offset via hardware register bit-cast. -}
writeFloat64LE :: BS.ByteString -> Int -> Double -> Maybe BS.ByteString
writeFloat64LE bs offset val = writeWord64LE bs offset (castDoubleToWord64 val)

{-| Read an unsigned 32-bit integer at a byte offset in little-endian order. -}
readWord32LE :: BS.ByteString -> Int -> Maybe Word32
readWord32LE bs offset
  | offset < 0 || offset + 4 > BS.length bs = Nothing
  | otherwise =
      let b0 = fromIntegral (BS.index bs offset)
          b1 = fromIntegral (BS.index bs (offset + 1))
          b2 = fromIntegral (BS.index bs (offset + 2))
          b3 = fromIntegral (BS.index bs (offset + 3))
       in Just (b0 .|. (b1 `shiftL` 8) .|. (b2 `shiftL` 16) .|. (b3 `shiftL` 24))

{-| Write an unsigned 32-bit integer at a byte offset in little-endian order. -}
writeWord32LE :: BS.ByteString -> Int -> Word32 -> Maybe BS.ByteString
writeWord32LE bs offset val
  | offset < 0 || offset + 4 > BS.length bs = Nothing
  | otherwise =
      let (before, rest) = BS.splitAt offset bs
          after = BS.drop 4 rest
          bytes =
            BS.pack
              [ fromIntegral (val .&. 0xFF)
              , fromIntegral ((val `shiftR` 8) .&. 0xFF)
              , fromIntegral ((val `shiftR` 16) .&. 0xFF)
              , fromIntegral ((val `shiftR` 24) .&. 0xFF)
              ]
       in Just (BS.concat [before, bytes, after])

{-| Fill a contiguous slice with a repeated byte value (vectorized memset). -}
fillBytes :: BS.ByteString -> Int -> Int -> Word8 -> Maybe BS.ByteString
fillBytes bs offset len val
  | len < 0 || offset < 0 = Nothing
  | offset + len > BS.length bs = Nothing
  | otherwise =
      let (before, rest) = BS.splitAt offset bs
          after = BS.drop len rest
          filled = BS.replicate len val
       in Just (BS.concat [before, filled, after])

{-| Lexicographically compare two byte slices (vectorized memcmp).
    Answers Just (-1) for LT, Just 0 for EQ, Just 1 for GT, or Nothing on out-of-bounds. -}
compareBytes :: BS.ByteString -> Int -> BS.ByteString -> Int -> Int -> Maybe Int
compareBytes bs1 off1 bs2 off2 len
  | len < 0 || off1 < 0 || off2 < 0 = Nothing
  | off1 + len > BS.length bs1 = Nothing
  | off2 + len > BS.length bs2 = Nothing
  | otherwise =
      let s1 = BS.take len (BS.drop off1 bs1)
          s2 = BS.take len (BS.drop off2 bs2)
       in Just (case compare s1 s2 of LT -> -1; EQ -> 0; GT -> 1)

{-| Copy a contiguous range of bytes from source to destination buffer. -}
copyBytes :: BS.ByteString -> Int -> BS.ByteString -> Int -> Int -> Maybe BS.ByteString
copyBytes src srcOff dst dstOff len
  | len < 0 || srcOff < 0 || dstOff < 0 = Nothing
  | srcOff + len > BS.length src = Nothing
  | dstOff + len > BS.length dst = Nothing
  | otherwise =
      let slice = BS.take len (BS.drop srcOff src)
          (before, rest) = BS.splitAt dstOff dst
          after = BS.drop len rest
       in Just (BS.concat [before, slice, after])

{-| Scan up to count 64-bit words starting at byte offset for a needle using 4-word unrolled loops.
    Answers the 0-based word index if found. -}
scanWord64 :: BS.ByteString -> Int -> Int -> Word64 -> Maybe Int
scanWord64 bs startByte count needle
  | startByte < 0 || count < 0 = Nothing
  | startByte + (count * 8) > BS.length bs = Nothing
  | otherwise = go 0
 where
  go i
    | i + 3 < count =
        let off0 = startByte + (i * 8)
            off1 = off0 + 8
            off2 = off0 + 16
            off3 = off0 + 24
            w0 = readWord64LE bs off0
            w1 = readWord64LE bs off1
            w2 = readWord64LE bs off2
            w3 = readWord64LE bs off3
         in case (w0, w1, w2, w3) of
              (Just w, _, _, _) | w == needle -> Just i
              (_, Just w, _, _) | w == needle -> Just (i + 1)
              (_, _, Just w, _) | w == needle -> Just (i + 2)
              (_, _, _, Just w) | w == needle -> Just (i + 3)
              _ -> go (i + 4)
    | i >= count = Nothing
    | otherwise =
        let off = startByte + (i * 8)
         in case readWord64LE bs off of
              Just w | w == needle -> Just i
              _ -> go (i + 1)
