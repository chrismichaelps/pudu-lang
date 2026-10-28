{-# LANGUAGE BangPatterns #-}

{-| @Runtime.Raster — depth-tested triangle rasterization into an RGBA8 target

    The software render device's only native work. Each call copies the color
    and depth targets once and writes every covered pixel of every triangle in
    place. Vertex data arrives as screen-space lanes, three vertices per
    triangle; transformation, clipping and shading inputs stay in Pudu. -}
module Pudu.Runtime.Raster
  ( Cull (..)
  , rasterFill
  , rasterTriangles
  , rasterPerspectiveTriangles
  ) where

import Control.Monad (when)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Internal as BI
import qualified Data.ByteString.Unsafe as BU
import Data.Word (Word8)
import Foreign.ForeignPtr (withForeignPtr)
import Foreign.Marshal.Utils (copyBytes)
import Foreign.Ptr (Ptr, castPtr)
import Foreign.Storable (peekElemOff, pokeByteOff, pokeElemOff)
import System.IO.Unsafe (unsafeDupablePerformIO)

import Pudu.Runtime.Lanes (Lanes, laneCount, laneFold)

{-| Which faces survive: front faces are counter-clockwise in normalized device
    coordinates, which is clockwise on a screen whose y grows downward. -}
data Cull = CullNone | CullBack
  deriving stock (Eq, Show)

{-| `pixels` RGBA8 pixels of one color, each channel clamped to [0, 1] and rounded. -}
rasterFill :: Int -> Double -> Double -> Double -> Double -> Maybe BS.ByteString
rasterFill pixels r g b a
  | pixels < 0 = Nothing
  | otherwise = Just $ BI.unsafeCreate (pixels * 4) $ \out ->
      let loop !i
            | i >= pixels = pure ()
            | otherwise = do
                pokeByteOff out (i * 4) (channel r)
                pokeByteOff out (i * 4 + 1) (channel g)
                pokeByteOff out (i * 4 + 2) (channel b)
                pokeByteOff out (i * 4 + 3) (channel a)
                loop (i + 1)
       in loop 0

{-| Rasterize triangles into copies of a color and a depth target. Answers
    Nothing when the targets disagree with the width, the vertex lanes differ
    in count, or the count is not a multiple of three. -}
rasterTriangles
  :: BS.ByteString -> Lanes -> Int -> Cull -> [Lanes] -> Maybe (BS.ByteString, Lanes)
rasterTriangles = rasterize Nothing

{-| Perspective attributes retain homogeneous w as the last lane. Positive finite
    weights are normalized per triangle before any reciprocal is formed. -}
rasterPerspectiveTriangles
  :: BS.ByteString -> Lanes -> Int -> Cull -> [Lanes] -> Maybe (BS.ByteString, Lanes)
rasterPerspectiveTriangles color depth width cull lanes = case lanes of
  [xs, ys, zs, rs, gs, bs, ws] -> rasterize (Just ws) color depth width cull [xs, ys, zs, rs, gs, bs]
  _ -> Nothing

rasterize
  :: Maybe Lanes -> BS.ByteString -> Lanes -> Int -> Cull -> [Lanes] -> Maybe (BS.ByteString, Lanes)
rasterize weights color depth width cull vertexLanes = case vertexLanes of
  [xs, ys, zs, rs, gs, bs]
    | width <= 0 || pixels `rem` width /= 0 -> Nothing
    | BS.length color /= pixels * 4 -> Nothing
    | any ((/= vertices) . laneCount) [ys, zs, rs, gs, bs] -> Nothing
    | vertices `rem` 3 /= 0 -> Nothing
    | not (maybe True validWeights weights) -> Nothing
    | otherwise -> Just $ unsafeDupablePerformIO $ do
        colorOut <- BI.mallocByteString (BS.length color)
        depthOut <- BI.mallocByteString (BS.length depth)
        withForeignPtr colorOut $ \c -> withForeignPtr depthOut $ \d ->
          BU.unsafeUseAsCString color $ \c0 -> BU.unsafeUseAsCString depth $ \d0 ->
            reading xs $ \px -> reading ys $ \py -> reading zs $ \pz ->
              reading rs $ \pr -> reading gs $ \pg -> reading bs $ \pb -> readingWeights weights $ \pw -> do
                copyBytes c (castPtr c0) (BS.length color)
                copyBytes d (castPtr d0) (BS.length depth)
                let target = Target c (castPtr d) width (pixels `quot` width)
                    triangles !t
                      | t >= vertices = pure ()
                      | otherwise = do
                          (q0, q1, q2) <- case pw of
                            Nothing -> pure (1, 1, 1)
                            Just pointer -> do
                              w0 <- peekElemOff pointer t
                              w1 <- peekElemOff pointer (t + 1)
                              w2 <- peekElemOff pointer (t + 2)
                              let smallest = min w0 (min w1 w2)
                              pure (smallest / w0, smallest / w1, smallest / w2)
                          let vertex i q = do
                                x <- peekElemOff px i
                                y <- peekElemOff py i
                                z <- peekElemOff pz i
                                r <- peekElemOff pr i
                                g <- peekElemOff pg i
                                b <- peekElemOff pb i
                                pure (Vertex x y z (r * q) (g * q) (b * q) q)
                          a <- vertex t q0
                          b <- vertex (t + 1) q1
                          v <- vertex (t + 2) q2
                          triangle target cull (maybe False (const True) weights) a b v
                          triangles (t + 3)
                triangles 0
        pure (BI.fromForeignPtr0 colorOut (BS.length color), BI.fromForeignPtr0 depthOut (BS.length depth))
    where
      pixels = laneCount depth
      vertices = laneCount xs
      validWeights lane = laneCount lane == vertices
        && laneFold (\ok w -> if ok == 1 && w > 0 && not (isInfinite w) then 1 else 0) 1 lane == 1
  _ -> Nothing

data Target = Target !(Ptr Word8) !(Ptr Double) !Int !Int

{-| Screen coordinates and affine depth, followed by weighted colors and their
    normalized reciprocal weight. The affine entry uses unit weights. -}
data Vertex = Vertex !Double !Double !Double !Double !Double !Double !Double

reading :: Lanes -> (Ptr Double -> IO a) -> IO a
reading bytes use = BU.unsafeUseAsCString bytes (use . castPtr)

readingWeights :: Maybe Lanes -> (Maybe (Ptr Double) -> IO a) -> IO a
readingWeights Nothing use = use Nothing
readingWeights (Just weights) use = reading weights (use . Just)

triangle :: Target -> Cull -> Bool -> Vertex -> Vertex -> Vertex -> IO ()
triangle target cull perspective v0 v1 v2
  | not (all usable [v0, v1, v2]) = pure ()
  | area == 0 = pure ()
  | cull == CullBack && area > 0 = pure ()
  | area < 0 = fill target perspective v0 v2 v1
  | otherwise = fill target perspective v0 v1 v2
  where
    area = edge v0 v1 (vx v2) (vy v2)
    usable (Vertex x y z _ _ _ _) = finite x && finite y && z >= 0 && z <= 1
    finite n = not (isNaN n || isInfinite n)

{-| Fill a triangle with positive edge area, sampling pixel centers. A pixel on
    an edge belongs to the triangle only for a top or left edge, so triangles
    sharing an edge cover every pixel exactly once. -}
fill :: Target -> Bool -> Vertex -> Vertex -> Vertex -> IO ()
fill (Target color depth width height) perspective v0 v1 v2 = rows lowY
  where
    area = edge v0 v1 (vx v2) (vy v2)
    inverse = 1 / area
    lowX = max 0 (floor (minimum [vx v0, vx v1, vx v2]))
    highX = min (width - 1) (ceiling (maximum [vx v0, vx v1, vx v2]))
    lowY = max 0 (floor (minimum [vy v0, vy v1, vy v2]))
    highY = min (height - 1) (ceiling (maximum [vy v0, vy v1, vy v2]))
    bias0 = topLeft v1 v2
    bias1 = topLeft v2 v0
    bias2 = topLeft v0 v1
    rows !y
      | y > highY = pure ()
      | otherwise = columns y lowX >> rows (y + 1)
    columns !y !x
      | x > highX = pure ()
      | otherwise = do
          let sx = fromIntegral x + 0.5
              sy = fromIntegral y + 0.5
              w0 = edge v1 v2 sx sy
              w1 = edge v2 v0 sx sy
              w2 = edge v0 v1 sx sy
          when (inside w0 bias0 && inside w1 bias1 && inside w2 bias2) $ do
            let l0 = w0 * inverse
                l1 = w1 * inverse
                l2 = w2 * inverse
                z = (l0 * vz v0 + l1 * vz v1) + l2 * vz v2
                reciprocal = if perspective then (l0 * vq v0 + l1 * vq v1) + l2 * vq v2 else 1
                at = y * width + x
            held <- peekElemOff depth at
            when (z < held && reciprocal > 0 && not (isInfinite reciprocal)) $ do
              pokeElemOff depth at z
              let shade f =
                    let value = (l0 * f v0 + l1 * f v1) + l2 * f v2
                     in channel (if perspective then value / reciprocal else value)
              pokeByteOff color (at * 4) (shade vr)
              pokeByteOff color (at * 4 + 1) (shade vg)
              pokeByteOff color (at * 4 + 2) (shade vb)
              pokeByteOff color (at * 4 + 3) (255 :: Word8)
          columns y (x + 1)
    inside w bias = w > 0 || (w == 0 && bias)

edge :: Vertex -> Vertex -> Double -> Double -> Double
edge a b x y = (vx b - vx a) * (y - vy a) - (vy b - vy a) * (x - vx a)

topLeft :: Vertex -> Vertex -> Bool
topLeft a b = (dy == 0 && dx > 0) || dy < 0
  where
    dx = vx b - vx a
    dy = vy b - vy a

channel :: Double -> Word8
channel value
  | isNaN value || value <= 0 = 0
  | value >= 1 = 255
  | otherwise = fromIntegral (round (value * 255) :: Int)

vx, vy, vz, vr, vg, vb, vq :: Vertex -> Double
vx (Vertex x _ _ _ _ _ _) = x
vy (Vertex _ y _ _ _ _ _) = y
vz (Vertex _ _ z _ _ _ _) = z
vr (Vertex _ _ _ r _ _ _) = r
vg (Vertex _ _ _ _ g _ _) = g
vb (Vertex _ _ _ _ _ b _) = b
vq (Vertex _ _ _ _ _ _ q) = q
