{-| Low-level unboxed contiguous byte buffer operations, independent of evaluator values. -}
module Pudu.Runtime.Buffer
  ( allocateBuffer
  , bufferSize
  , readWord64LE
  , writeWord64LE
  , readInt64LE
  , writeInt64LE
  , readFloat64LE
  , copyBytes
  , scanWord64
  ) where

import Data.Bits ((.&.), (.|.), shiftL, shiftR)
import qualified Data.ByteString as BS
import Data.Int (Int64)
import Data.Word (Word64)

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

{-| Read an IEEE-754 64-bit floating point number at a byte offset. -}
readFloat64LE :: BS.ByteString -> Int -> Maybe Double
readFloat64LE bs offset = do
  w <- readWord64LE bs offset
  pure (decodeFloat64 w)

decodeFloat64 :: Word64 -> Double
decodeFloat64 w =
  let sign = if (w `shiftR` 63) == 1 then -1.0 else 1.0
      exponentBits = fromIntegral ((w `shiftR` 52) .&. 0x7FF) :: Int
      mantissaBits = w .&. 0x000FFFFFFFFFFFFF
   in if exponentBits == 0
        then
          if mantissaBits == 0
            then sign * 0.0
            else sign * (fromIntegral mantissaBits / (2.0 ** 1074.0))
        else
          if exponentBits == 2047
            then
              if mantissaBits == 0
                then sign * (1.0 / 0.0) -- Infinity
                else 0.0 / 0.0         -- NaN
            else
              let mantissa = 1.0 + (fromIntegral mantissaBits / (2.0 ** 52.0))
                  expVal = 2.0 ** fromIntegral (exponentBits - 1023)
               in sign * mantissa * expVal

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

{-| Scan up to count 64-bit words starting at byte offset for a needle.
    Answers the 0-based word index if found. -}
scanWord64 :: BS.ByteString -> Int -> Int -> Word64 -> Maybe Int
scanWord64 bs startByte count needle
  | startByte < 0 || count < 0 = Nothing
  | startByte + (count * 8) > BS.length bs = Nothing
  | otherwise = go 0
 where
  go i
    | i >= count = Nothing
    | otherwise =
        let off = startByte + (i * 8)
         in case readWord64LE bs off of
              Just w | w == needle -> Just i
              _ -> go (i + 1)
