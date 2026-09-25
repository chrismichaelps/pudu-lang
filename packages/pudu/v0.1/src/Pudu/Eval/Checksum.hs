{-| @Eval.Checksum.Module — checksums the library cannot afford to loop over

    `Std.Checksum` is the surface a program writes against. A checksum costs
    one table step per byte, and the evaluator spends about a microsecond on
    each, so written in Pudu a megabyte took over six seconds — a checksum a
    transfer cannot wait for. The same boundary `Pudu.Eval.Hash` draws for
    digests is drawn here: the arithmetic lives in the runtime, and the
    fixtures check it against each algorithm's published values.

    Every function takes the previous result and answers the next, so a stream
    is checked a chunk at a time and a whole buffer is the stream of one chunk.
    Nothing here reaches outside the program, which is what lets a constant be
    folded through one. -}
module Pudu.Eval.Checksum
  ( ChecksumKind (..)
  , checksumKindOf
  , checksumUpdate
  ) where

import Data.Bits (shiftR, xor, (.&.))
import qualified Data.ByteString as ByteString
import Data.Word (Word32, Word64, Word8)

{-| The algorithms, in the order of the codes `Std.Checksum` passes. A code
    is used rather than a named sum because a wired-in signature cannot
    mention a type a library module declares. -}
data ChecksumKind
  = Crc32Ieee
  | Crc32Castagnoli
  | Crc64Ecma
  | Fnv1a32
  | Fnv1a64
  deriving (Eq, Show)

checksumKindOf :: Integer -> Maybe ChecksumKind
checksumKindOf code = case code of
  0 -> Just Crc32Ieee
  1 -> Just Crc32Castagnoli
  2 -> Just Crc64Ecma
  3 -> Just Fnv1a32
  4 -> Just Fnv1a64
  _ -> Nothing

{-| The checksum after `previous` of the bytes. A CRC's previous value is its
    finished result, inverted back into a register here, so chaining two calls
    answers exactly what one call over both chunks answers. -}
checksumUpdate :: ChecksumKind -> Word64 -> ByteString.ByteString -> Word64
checksumUpdate kind previous bytes = case kind of
  Crc32Ieee -> fromIntegral (crc32With 0xedb88320 (fromIntegral previous) bytes)
  Crc32Castagnoli -> fromIntegral (crc32With 0x82f63b78 (fromIntegral previous) bytes)
  Crc64Ecma -> crc64With 0xc96c5795d7870f42 previous bytes
  Fnv1a32 -> fromIntegral (ByteString.foldl' fnv32Step (fromIntegral previous) bytes)
  Fnv1a64 -> ByteString.foldl' fnv64Step previous bytes

crc32With :: Word32 -> Word32 -> ByteString.ByteString -> Word32
crc32With polynomial previous bytes =
  complement32 (ByteString.foldl' step (complement32 previous) bytes)
 where
  step register octet = shiftEight (register `xor` fromIntegral octet)
  shiftEight value = bit (bit (bit (bit (bit (bit (bit (bit value)))))))
  bit value
    | value .&. 1 == 1 = (value `shiftR` 1) `xor` polynomial
    | otherwise = value `shiftR` 1
  complement32 value = value `xor` 0xffffffff

crc64With :: Word64 -> Word64 -> ByteString.ByteString -> Word64
crc64With polynomial previous bytes =
  complement64 (ByteString.foldl' step (complement64 previous) bytes)
 where
  step register octet = shiftEight (register `xor` fromIntegral octet)
  shiftEight value = bit (bit (bit (bit (bit (bit (bit (bit value)))))))
  bit value
    | value .&. 1 == 1 = (value `shiftR` 1) `xor` polynomial
    | otherwise = value `shiftR` 1
  complement64 value = value `xor` 0xffffffffffffffff

fnv32Step :: Word32 -> Word8 -> Word32
fnv32Step state octet = (state `xor` fromIntegral octet) * 0x01000193

fnv64Step :: Word64 -> Word8 -> Word64
fnv64Step state octet = (state `xor` fromIntegral octet) * 0x100000001b3
