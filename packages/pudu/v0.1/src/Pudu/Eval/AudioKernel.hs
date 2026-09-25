{-| @Eval.AudioKernel — exact bounded PCM arithmetic without interpreter dispatch. -}
module Pudu.Eval.AudioKernel
  ( rampBytes
  , toneBytes
  ) where

import qualified Data.ByteString as Bytes
import Data.Word (Word8)

toneBytes :: Integer -> Integer -> Integer -> Integer -> Integer -> Integer -> Maybe Bytes.ByteString
toneBytes wave period amplitude channels start frames
  | wave < 0 || wave > 2 = Nothing
  | period < 2 = Nothing
  | amplitude < 0 || amplitude > 32767 = Nothing
  | channels < 1 || channels > 8 = Nothing
  | start < 0 || frames < 0 || frames > 4096 = Nothing
  | otherwise = Just (Bytes.pack octets)
 where
  octets = concatMap encodedSample samples
  samples =
    [ waveAt wave ((start + frame) `rem` period) period amplitude
    | frame <- [0 .. frames - 1]
    , _channel <- [1 .. channels]
    ]

rampBytes
  :: Bytes.ByteString
  -> Integer
  -> Integer
  -> Integer
  -> Integer
  -> Integer
  -> Integer
  -> Maybe Bytes.ByteString
rampBytes source channels start fromFrame fromGain toFrame toGain
  | channels < 1 || channels > 8 = Nothing
  | start < 0 || fromFrame < 0 || toFrame <= fromFrame = Nothing
  | fromGain < 0 || fromGain > 131072 = Nothing
  | toGain < 0 || toGain > 131072 = Nothing
  | Bytes.length source > 4096 * fromInteger channels * 2 = Nothing
  | Bytes.length source `rem` (fromInteger channels * 2) /= 0 = Nothing
  | otherwise = Just (Bytes.pack (concatMap encodedSample (scaledSamples 0 (Bytes.unpack source))))
 where
  scaledSamples _ [] = []
  scaledSamples index (low : high : rest) =
    let frame = start + index `quot` channels
        amount
          | frame <= fromFrame = fromGain
          | frame >= toFrame = toGain
          | otherwise =
              fromGain
                + ((toGain - fromGain) * (frame - fromFrame)) `quot` (toFrame - fromFrame)
        sample = decodedSample low high
     in saturated (roundedQ15 (sample * amount)) : scaledSamples (index + 1) rest
  scaledSamples _ _ = []

waveAt :: Integer -> Integer -> Integer -> Integer -> Integer
waveAt wave phase period amplitude = case wave of
  0 -> if phase * 2 < period then amplitude else negate amplitude
  1 -> negate amplitude + (2 * amplitude * phase) `quot` period
  _ ->
    let half = period `quot` 2
     in if phase < half
          then negate amplitude + (2 * amplitude * phase) `quot` half
          else amplitude - (2 * amplitude * (phase - half)) `quot` (period - half)

roundedQ15 :: Integer -> Integer
roundedQ15 value
  | value >= 0 = (value + 16384) `quot` 32768
  | otherwise = negate ((16384 - value) `quot` 32768)

saturated :: Integer -> Integer
saturated value
  | value > 32767 = 32767
  | value < -32768 = -32768
  | otherwise = value

decodedSample :: Word8 -> Word8 -> Integer
decodedSample low high =
  let word = toInteger low + toInteger high * 256
   in if word >= 32768 then word - 65536 else word

encodedSample :: Integer -> [Word8]
encodedSample sample =
  let word = sample `mod` 65536
   in [fromInteger (word `mod` 256), fromInteger (word `quot` 256)]
