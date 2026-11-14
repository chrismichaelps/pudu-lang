{-# LANGUAGE BangPatterns #-}

{-| @Runtime.Sampler — clamp-to-edge RGBA8 texture sampling for the raster driver

    Texels decode to straight-alpha linear light. Bilinear filtering works on
    premultiplied values so transparent texels carry no color into their
    neighbours; the rules match the checked Pudu texture sampler. -}
module Pudu.Runtime.Sampler
  ( Sampler
  , Pinned
  , Texel (..)
  , sampler
  , withSampler
  , sample
  ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Unsafe as BU
import Data.Word (Word8)
import Foreign.Ptr (Ptr, castPtr)
import Foreign.Storable (peekByteOff, peekElemOff)

import Pudu.Runtime.Lanes (Lanes, laneFromList)

{-| Validated texture storage: texels, width, height, sRGB and bilinear flags. -}
data Sampler = Sampler !BS.ByteString !Int !Int !Bool !Bool

{-| Pinned texels and the decode table for one raster call. -}
data Pinned = Pinned !(Ptr Word8) !(Ptr Double) !Int !Int !Bool !Bool

{-| Straight-alpha linear red, green, blue and alpha. -}
data Texel = Texel !Double !Double !Double !Double

{-| Checked RGBA8 storage with color-space code 0 linear / 1 sRGB and filter
    code 0 nearest / 1 bilinear. -}
sampler :: BS.ByteString -> Int -> Int -> Int -> Maybe Sampler
sampler texels width space filtering
  | width <= 0 || bytes `rem` 4 /= 0 = Nothing
  | pixels == 0 || pixels `rem` width /= 0 = Nothing
  | space `notElem` [0, 1] || filtering `notElem` [0, 1] = Nothing
  | otherwise = Just (Sampler texels width (pixels `quot` width) (space == 1) (filtering == 1))
  where
    bytes = BS.length texels
    pixels = bytes `quot` 4

{-| Pin the texels and the decode table while the action samples. -}
withSampler :: Sampler -> (Pinned -> IO a) -> IO a
withSampler (Sampler texels width height srgb bilinear) use =
  BU.unsafeUseAsCString texels $ \t -> BU.unsafeUseAsCString decodeTable $ \d ->
    use (Pinned (castPtr t) (castPtr d) width height srgb bilinear)

{-| Sample at a normalized UV; non-finite coordinates answer transparent black. -}
sample :: Pinned -> Double -> Double -> IO Texel
sample pinned@(Pinned _ _ width height _ bilinear) u v
  | not (finite u && finite v) = pure (Texel 0 0 0 0)
  | not bilinear = texel pinned (bounded width (floor (cu * w))) (bounded height (floor (cv * h)))
  | otherwise = do
      let x = cu * w - 0.5
          y = cv * h - 0.5
          left = floor x
          top = floor y
          tx = x - fromIntegral left
          ty = y - fromIntegral top
          at i j = premultiplied <$> texel pinned (bounded width i) (bounded height j)
      a <- at left top
      b <- at (left + 1) top
      c <- at left (top + 1)
      d <- at (left + 1) (top + 1)
      let Texel r g bl al = mix (mix a b tx) (mix c d tx) ty
      pure $ if al == 0 then Texel 0 0 0 0 else Texel (r / al) (g / al) (bl / al) al
  where
    w = fromIntegral width
    h = fromIntegral height
    cu = clamp01 u
    cv = clamp01 v

texel :: Pinned -> Int -> Int -> IO Texel
texel (Pinned texels table width _ srgb _) x y = do
  let at = (y * width + x) * 4
      decode offset = do
        byte <- peekByteOff texels (at + offset) :: IO Word8
        let index = fromIntegral byte
        if srgb then peekElemOff table index else pure (fromIntegral index / 255)
  r <- decode 0
  g <- decode 1
  b <- decode 2
  alpha <- peekByteOff texels (at + 3) :: IO Word8
  pure (Texel r g b (fromIntegral alpha / 255))

premultiplied :: Texel -> Texel
premultiplied (Texel r g b a) = Texel (r * a) (g * a) (b * a) a

mix :: Texel -> Texel -> Double -> Texel
mix (Texel r0 g0 b0 a0) (Texel r1 g1 b1 a1) t =
  Texel (lerp r0 r1) (lerp g0 g1) (lerp b0 b1) (lerp a0 a1)
  where
    lerp from to
      | t == 0 = from
      | t == 1 = to
      | otherwise = from + t * (to - from)

{-| The exact piecewise sRGB transfer for every eight-bit code. -}
decodeTable :: Lanes
decodeTable = laneFromList [transfer (fromIntegral code / 255) | code <- [0 .. 255 :: Int]]
  where
    transfer encoded
      | encoded <= 0.04045 = encoded / 12.92
      | otherwise = ((encoded + 0.055) / 1.055) ** 2.4
{-# NOINLINE decodeTable #-}

bounded :: Int -> Int -> Int
bounded size index
  | index < 0 = 0
  | index >= size = size - 1
  | otherwise = index

clamp01 :: Double -> Double
clamp01 x
  | x < 0 = 0
  | x > 1 = 1
  | otherwise = x

finite :: Double -> Bool
finite x = not (isNaN x || isInfinite x)
