{-| @Eval.Hash.Module — hashing the library cannot afford to write itself

    `Std.Crypto` implements SHA-256 in Pudu, and that implementation is the
    evidence that the language's bit work is correct: it produces byte-exact
    digests for the algorithm's published vectors. It is kept.

    What it cannot do is be used in a loop. A digest of a short message
    measures 23.6 ms unoptimised, and the key derivation a database handshake
    performs is four thousand and ninety-six iterations of two digests each —
    a minute of arithmetic to open one connection. The same figure is what
    stops a hash map: a lookup that hashes its key cannot pay a digest for it.

    So the algorithms live here as well, and the boundary is visible: a program
    that wants to read how SHA-256 works reads `Std.Crypto`, and one that needs
    to run it many times reaches these. Both answer the same digests, which the
    fixtures check against each other. -}
module Pudu.Eval.Hash
  ( hashOfBytes
  , hashOfValue
  , hmacSha256
  , pbkdf2Sha256
  , sha256
  ) where

import qualified Crypto.Hash as Hash
import qualified Crypto.KDF.PBKDF2 as Pbkdf2
import qualified Crypto.MAC.HMAC as Hmac
import Data.Bits (shiftR, xor, (.&.))
import qualified Data.ByteArray as ByteArray
import qualified Data.ByteString as ByteString
import qualified Data.Text.Encoding as Encoding
import Data.Word (Word64, Word8)
import Pudu.Eval.Render (renderValue)
import Pudu.Eval.Value (Value (..))





{-| The SHA-256 digest of bytes, as its thirty-two bytes. -}
sha256 :: ByteString.ByteString -> ByteString.ByteString
sha256 message = ByteArray.convert (Hash.hash message :: Hash.Digest Hash.SHA256)




{-| The keyed digest, which is what proves a message came from someone holding
    the key rather than only that it was not altered.

    A key longer than a block is replaced by its own digest, and a shorter one
    padded with zeros, exactly as the construction requires. Getting either
    wrong produces a value that looks like a digest and authenticates nothing. -}
hmacSha256 :: ByteString.ByteString -> ByteString.ByteString -> ByteString.ByteString
hmacSha256 key message =
  ByteArray.convert (Hmac.hmac key message :: Hmac.HMAC Hash.SHA256)


{-| A key derived from a password by iterating the keyed digest.

    The iteration count is the point: it is what makes guessing a password cost
    the guesser the same as it cost the owner, once, and it is why this cannot
    be written in the language at the speed the language currently runs. -}
pbkdf2Sha256
  :: ByteString.ByteString -> ByteString.ByteString -> Int -> Int -> ByteString.ByteString
pbkdf2Sha256 password salt iterations wanted =
  Pbkdf2.fastPBKDF2_SHA256
    Pbkdf2.Parameters{Pbkdf2.iterCounts = iterations, Pbkdf2.outputLength = wanted}
    password
    salt



{-| A number for a value, for a collection that reaches its entries by one.

    Not a digest. This is the mixing a hash map wants — cheap, well spread, and
    stable within a run — and it is deliberately not offered as anything else:
    a value hashed with this is not hidden, and two programs are not promised
    the same number for the same value. `sha256` is what a caller needing
    either of those reaches for.

    A value is hashed through the text it renders as, so two values that print
    the same hash the same and every shape the language has is covered without
    this needing a case for each. That costs the rendering, which is why the
    byte and text cases below skip it. -}
hashOfValue :: Value -> Integer
hashOfValue value = case value of
  StrValue text -> hashOfBytes (Encoding.encodeUtf8 text)
  BytesValue bytes -> hashOfBytes bytes
  IntValue _ number -> mixInteger number
  other -> hashOfBytes (Encoding.encodeUtf8 (renderValue other))

{-| The bytes mixed into one number, by the multiply-and-exclusive-or walk that
    spreads a changed byte across the whole result rather than leaving it in
    the position it changed. -}
hashOfBytes :: ByteString.ByteString -> Integer
hashOfBytes = fromIntegral . ByteString.foldl' step (0xcbf29ce484222325 :: Word64)
 where
  step accumulated byte = (accumulated `xor` fromIntegral byte) * 0x100000001b3

{-| An integer mixed without rendering it, since a number is the commonest key
    and rendering one to hash it would be the whole cost of the lookup. -}
mixInteger :: Integer -> Integer
mixInteger number =
  hashOfBytes (ByteString.pack (bytesOfInteger (abs number) <> [sign]))
 where
  sign = if number < 0 then 1 else 0 :: Word8

bytesOfInteger :: Integer -> [Word8]
bytesOfInteger number
  | number == 0 = [0]
  | otherwise = go number []
 where
  go remaining built
    | remaining == 0 = built
    | otherwise = go (remaining `shiftR` 8) (fromIntegral (remaining .&. 0xff) : built)
