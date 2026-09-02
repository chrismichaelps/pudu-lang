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

import Data.Bits (complement, shiftL, shiftR, xor, (.&.), (.|.))
import qualified Data.ByteString as ByteString
import qualified Data.Text.Encoding as Encoding
import Data.Word (Word32, Word64, Word8)
import Pudu.Eval.Render (renderValue)
import Pudu.Eval.Value (Value (..))

{-| The constants SHA-256 mixes in, one per round. They are the fractional
    parts of the cube roots of the first sixty-four primes, which is how the
    algorithm says it chose numbers nobody picked. -}
roundConstants :: [Word32]
roundConstants =
  [ 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5
  , 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
  , 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3
  , 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174
  , 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc
  , 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
  , 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7
  , 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967
  , 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13
  , 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
  , 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3
  , 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
  , 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5
  , 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
  , 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208
  , 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ]

initialState :: [Word32]
initialState =
  [ 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
  , 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  ]

rotateRight :: Word32 -> Int -> Word32
rotateRight value places = (value `shiftR` places) .|. (value `shiftL` (32 - places))

{-| The message with the padding the algorithm requires: a single one bit, then
    zeros, then the original length in bits as a sixty-four bit number. -}
padded :: ByteString.ByteString -> ByteString.ByteString
padded message =
  ByteString.concat [message, ByteString.singleton 0x80, ByteString.replicate zeros 0, lengthBytes]
 where
  size = ByteString.length message
  zeros = (55 - size) `mod` 64
  bitLength = fromIntegral size * 8 :: Word64
  lengthBytes =
    ByteString.pack [fromIntegral (bitLength `shiftR` (8 * (7 - index))) | index <- [0 .. 7]]

{-| The SHA-256 digest of bytes, as its thirty-two bytes. -}
sha256 :: ByteString.ByteString -> ByteString.ByteString
sha256 message =
  ByteString.pack (concatMap wordBytes (foldl' compress initialState blocks))
 where
  prepared = padded message
  blocks =
    [ ByteString.take 64 (ByteString.drop offset prepared)
    | offset <- [0, 64 .. ByteString.length prepared - 1]
    ]
  wordBytes value = [fromIntegral (value `shiftR` (8 * (3 - index))) | index <- [0 .. 3]]

{-| The sixty-four words one block expands into.

    The first sixteen are the block read as big-endian numbers; each of the
    rest is built from four earlier ones. Written as a list that refers to
    itself, which is what lets the later entries be defined in terms of the
    earlier ones without a mutable buffer. -}
messageSchedule :: ByteString.ByteString -> [Word32]
messageSchedule block = built
 where
  built = first16 <> [expanded index | index <- [16 .. 63]]
  first16 = [wordAt at | at <- [0, 4 .. 60]]
  wordAt at =
    foldl'
      (\acc index -> (acc `shiftL` 8) .|. fromIntegral (ByteString.index block (at + index)))
      0
      [0 .. 3]
  expanded index =
    let w15 = built !! (index - 15)
        w2 = built !! (index - 2)
        s0 = rotateRight w15 7 `xor` rotateRight w15 18 `xor` (w15 `shiftR` 3)
        s1 = rotateRight w2 17 `xor` rotateRight w2 19 `xor` (w2 `shiftR` 10)
     in built !! (index - 16) + s0 + built !! (index - 7) + s1

{-| One block folded into the state. -}
compress :: [Word32] -> ByteString.ByteString -> [Word32]
compress state block =
  zipWith (+) state (foldl' step state (zip roundConstants (messageSchedule block)))
 where
  step working (constant, scheduled) = case working of
    [a, b, c, d, e, f, g, h] ->
      let s1 = rotateRight e 6 `xor` rotateRight e 11 `xor` rotateRight e 25
          choice = (e .&. f) `xor` (complement e .&. g)
          temp1 = h + s1 + choice + constant + scheduled
          s0 = rotateRight a 2 `xor` rotateRight a 13 `xor` rotateRight a 22
          majority = (a .&. b) `xor` (a .&. c) `xor` (b .&. c)
          temp2 = s0 + majority
       in [temp1 + temp2, a, b, c, d + temp1, e, f, g]
    other -> other

{-| The keyed digest, which is what proves a message came from someone holding
    the key rather than only that it was not altered.

    A key longer than a block is replaced by its own digest, and a shorter one
    padded with zeros, exactly as the construction requires. Getting either
    wrong produces a value that looks like a digest and authenticates nothing. -}
hmacSha256 :: ByteString.ByteString -> ByteString.ByteString -> ByteString.ByteString
hmacSha256 key message = sha256 (outerKey <> sha256 (innerKey <> message))
 where
  blockSize = 64
  shortened = if ByteString.length key > blockSize then sha256 key else key
  prepared = shortened <> ByteString.replicate (blockSize - ByteString.length shortened) 0
  innerKey = ByteString.map (`xor` 0x36) prepared
  outerKey = ByteString.map (`xor` 0x5c) prepared

{-| A key derived from a password by iterating the keyed digest.

    The iteration count is the point: it is what makes guessing a password cost
    the guesser the same as it cost the owner, once, and it is why this cannot
    be written in the language at the speed the language currently runs. -}
pbkdf2Sha256
  :: ByteString.ByteString -> ByteString.ByteString -> Int -> Int -> ByteString.ByteString
pbkdf2Sha256 password salt iterations wanted =
  ByteString.take wanted (ByteString.concat (map derive [1 .. blocksNeeded]))
 where
  hashLength = 32
  blocksNeeded = max 1 ((wanted + hashLength - 1) `div` hashLength)
  derive index = walk first first (iterations - 1)
   where
    counter =
      ByteString.pack [fromIntegral (index `shiftR` (8 * (3 - at))) | at <- [0 .. 3]]
    first = hmacSha256 password (salt <> counter)

  {-| Each step needs both the running exclusive-or and the digest the next
      step derives from, so both are carried. Folding over one of them alone
      would have to recompute the other every time round. -}
  walk accumulated previous remaining
    | remaining <= 0 = accumulated
    | otherwise =
        let next = hmacSha256 password previous
         in walk (exclusiveOr accumulated next) next (remaining - 1)

exclusiveOr :: ByteString.ByteString -> ByteString.ByteString -> ByteString.ByteString
exclusiveOr left right = ByteString.pack (ByteString.zipWith xor left right)

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
