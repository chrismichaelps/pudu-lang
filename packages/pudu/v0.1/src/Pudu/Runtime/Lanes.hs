{-# LANGUAGE BangPatterns #-}

{-| @Runtime.Lanes — whole-lane binary64 kernels over contiguous native storage

    Lanes are a ByteString of host-order binary64 values. Every kernel makes one
    pass with no intermediate list and allocates exactly its result. Sums run in
    index order, so a kernel's result equals the scalar loop written the same way. -}
module Pudu.Runtime.Lanes
  ( Lanes
  , laneAffine3
  , laneConcat
  , laneCount
  , laneFill
  , laneFold
  , laneFromList
  , laneGather
  , laneGet
  , laneInterleave
  , laneMap
  , laneRamp
  , laneScatter
  , laneScatterAdd
  , laneWhere
  , laneSet
  , laneSlice
  , laneToList
  , laneToPcm16
  , laneWhole
  , laneZip
  , laneZip3
  ) where

import Control.Monad (forM_)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Internal as BI
import qualified Data.ByteString.Unsafe as BU
import Foreign.Marshal.Utils (copyBytes)
import Foreign.Ptr (Ptr, castPtr)
import Data.Word (Word8)
import Foreign.Storable (peekElemOff, pokeByteOff, pokeElemOff)
import System.IO.Unsafe (unsafeDupablePerformIO)

type Lanes = BS.ByteString

{-| Whether the bytes hold a whole number of binary64 values. -}
laneWhole :: Lanes -> Bool
laneWhole bytes = BS.length bytes `rem` 8 == 0

laneCount :: Lanes -> Int
laneCount bytes = BS.length bytes `quot` 8
{-# INLINE laneCount #-}

create :: Int -> (Ptr Double -> IO ()) -> Lanes
create count fill = BI.unsafeCreate (count * 8) (fill . castPtr)
{-# INLINE create #-}

reading :: Lanes -> (Ptr Double -> IO a) -> IO a
reading bytes use = BU.unsafeUseAsCString bytes (use . castPtr)
{-# INLINE reading #-}

laneFill :: Int -> Double -> Maybe Lanes
laneFill count value
  | count < 0 = Nothing
  | otherwise = Just $ create count $ \out -> forM_ [0 .. count - 1] $ \i -> pokeElemOff out i value

{-| `start + i * step` for each index, multiplied before adding. -}
laneRamp :: Int -> Double -> Double -> Maybe Lanes
laneRamp count start step
  | count < 0 = Nothing
  | otherwise = Just $ create count $ \out ->
      forM_ [0 .. count - 1] $ \i -> pokeElemOff out i (start + fromIntegral i * step)

laneFromList :: [Double] -> Lanes
laneFromList values = create (length values) $ \out -> go out 0 values
  where
    go _ _ [] = pure ()
    go out !i (value : rest) = pokeElemOff out i value >> go out (i + 1) rest

laneToList :: Lanes -> [Double]
laneToList bytes = unsafeDupablePerformIO $ reading bytes $ \source ->
  mapM (peekElemOff source) [0 .. laneCount bytes - 1]

laneGet :: Lanes -> Int -> Maybe Double
laneGet bytes index
  | index < 0 || index >= laneCount bytes = Nothing
  | otherwise = Just $ unsafeDupablePerformIO $ reading bytes $ \source -> peekElemOff source index

{-| A copy with one value replaced; a single-element edit, not a loop primitive. -}
laneSet :: Lanes -> Int -> Double -> Maybe Lanes
laneSet bytes index value
  | index < 0 || index >= laneCount bytes = Nothing
  | otherwise = Just $ unsafeDupablePerformIO $ reading bytes $ \source ->
      pure $ create (laneCount bytes) $ \out -> do
        copyBytes out source (BS.length bytes)
        pokeElemOff out index value

laneSlice :: Lanes -> Int -> Int -> Maybe Lanes
laneSlice bytes start count
  | start < 0 || count < 0 || start + count > laneCount bytes = Nothing
  | otherwise = Just (BS.copy (BS.take (count * 8) (BS.drop (start * 8) bytes)))

laneConcat :: Lanes -> Lanes -> Lanes
laneConcat = BS.append

laneMap :: (Double -> Double) -> Lanes -> Lanes
laneMap f bytes = unsafeDupablePerformIO $ reading bytes $ \source ->
  pure $ create count $ \out -> loop source out 0
  where
    count = laneCount bytes
    loop source out !i
      | i >= count = pure ()
      | otherwise = do
          x <- peekElemOff source i
          pokeElemOff out i (f x)
          loop source out (i + 1)
{-# INLINE laneMap #-}

laneZip :: (Double -> Double -> Double) -> Lanes -> Lanes -> Maybe Lanes
laneZip f left right
  | laneCount left /= laneCount right = Nothing
  | otherwise = Just $ unsafeDupablePerformIO $ reading left $ \a -> reading right $ \b ->
      pure $ create count $ \out -> loop a b out 0
  where
    count = laneCount left
    loop a b out !i
      | i >= count = pure ()
      | otherwise = do
          x <- peekElemOff a i
          y <- peekElemOff b i
          pokeElemOff out i (f x y)
          loop a b out (i + 1)
{-# INLINE laneZip #-}

laneZip3 :: (Double -> Double -> Double -> Double) -> Lanes -> Lanes -> Lanes -> Maybe Lanes
laneZip3 f first second third
  | laneCount first /= laneCount second || laneCount first /= laneCount third = Nothing
  | otherwise = Just $ unsafeDupablePerformIO $ reading first $ \a -> reading second $ \b -> reading third $ \c ->
      pure $ create count $ \out -> loop a b c out 0
  where
    count = laneCount first
    loop a b c out !i
      | i >= count = pure ()
      | otherwise = do
          x <- peekElemOff a i
          y <- peekElemOff b i
          z <- peekElemOff c i
          pokeElemOff out i (f x y z)
          loop a b c out (i + 1)
{-# INLINE laneZip3 #-}

{-| A strict left fold in index order. -}
laneFold :: (Double -> Double -> Double) -> Double -> Lanes -> Double
laneFold f initial bytes = unsafeDupablePerformIO $ reading bytes $ \source -> loop source initial 0
  where
    count = laneCount bytes
    loop source !acc !i
      | i >= count = pure acc
      | otherwise = peekElemOff source i >>= \x -> loop source (f acc x) (i + 1)
{-# INLINE laneFold #-}

laneGather :: Lanes -> [Int] -> Maybe Lanes
laneGather bytes indices
  | any (\i -> i < 0 || i >= limit) indices = Nothing
  | otherwise = Just $ unsafeDupablePerformIO $ reading bytes $ \source ->
      pure $ create (length indices) $ \out ->
        forM_ (zip [0 ..] indices) $ \(slot, index) -> peekElemOff source index >>= pokeElemOff out slot
  where
    limit = laneCount bytes

{-| Write each value at its index in a copy; a later index wins on repeats. -}
laneScatter :: Lanes -> [Int] -> Lanes -> Maybe Lanes
laneScatter bytes indices values
  | length indices /= laneCount values = Nothing
  | any (\i -> i < 0 || i >= limit) indices = Nothing
  | otherwise = Just $ unsafeDupablePerformIO $ reading bytes $ \source -> reading values $ \fresh ->
      pure $ create limit $ \out -> do
        copyBytes out source (BS.length bytes)
        forM_ (zip [0 ..] indices) $ \(slot, index) -> peekElemOff fresh slot >>= pokeElemOff out index
  where
    limit = laneCount bytes

{-| Apply a column-major 3x4 affine matrix to x/y/z lanes, preserving the
    written order ((m0 x + m3 y) + m6 z) + m9 for each output row. -}
laneAffine3 :: [Double] -> Lanes -> Lanes -> Lanes -> Maybe (Lanes, Lanes, Lanes)
laneAffine3 matrix xs ys zs = case matrix of
  [m0, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11] -> do
    rx <- laneZip3 (\x y z -> ((m0 * x + m3 * y) + m6 * z) + m9) xs ys zs
    ry <- laneZip3 (\x y z -> ((m1 * x + m4 * y) + m7 * z) + m10) xs ys zs
    rz <- laneZip3 (\x y z -> ((m2 * x + m5 * y) + m8 * z) + m11) xs ys zs
    pure (rx, ry, rz)
  _ -> Nothing

{-| Indices whose value is positive, ascending; NaN is not positive. -}
laneWhere :: Lanes -> [Int]
laneWhere bytes = [index | (index, value) <- zip [0 ..] (laneToList bytes), value > 0]

{-| Add each value at its index in a copy; repeated indices accumulate in the
    order given, so a sum is the same on every run. -}
laneScatterAdd :: Lanes -> [Int] -> Lanes -> Maybe Lanes
laneScatterAdd bytes indices values
  | length indices /= laneCount values = Nothing
  | any (\i -> i < 0 || i >= limit) indices = Nothing
  | otherwise = Just $ unsafeDupablePerformIO $ reading bytes $ \source -> reading values $ \fresh ->
      pure $ create limit $ \out -> do
        copyBytes out source (BS.length bytes)
        forM_ (zip [0 ..] indices) $ \(slot, index) -> do
          held <- peekElemOff out index
          added <- peekElemOff fresh slot
          pokeElemOff out index (held + added)
  where
    limit = laneCount bytes

{-| Two equally long lanes alternated element by element: a0, b0, a1, b1, ... -}
laneInterleave :: Lanes -> Lanes -> Maybe Lanes
laneInterleave left right
  | laneCount left /= laneCount right = Nothing
  | otherwise = Just $ unsafeDupablePerformIO $ reading left $ \a -> reading right $ \b ->
      pure $ create (count * 2) $ \out -> loop a b out 0
  where
    count = laneCount left
    loop a b out !i
      | i >= count = pure ()
      | otherwise = do
          peekElemOff a i >>= pokeElemOff out (i * 2)
          peekElemOff b i >>= pokeElemOff out (i * 2 + 1)
          loop a b out (i + 1)

{-| Signed little-endian 16-bit samples: each value clamped to [-1, 1], scaled
    by 32767 and rounded half away from zero; NaN becomes silence. -}
laneToPcm16 :: Lanes -> BS.ByteString
laneToPcm16 bytes = unsafeDupablePerformIO $ reading bytes $ \source ->
  pure $ BI.unsafeCreate (count * 2) $ \out -> loop source out 0
  where
    count = laneCount bytes
    loop source out !i
      | i >= count = pure ()
      | otherwise = do
          x <- peekElemOff source i
          let sample = quantize x :: Int
              word = fromIntegral (if sample < 0 then sample + 65536 else sample) :: Int
          pokeByteOff out (i * 2) (fromIntegral (word `rem` 256) :: Word8)
          pokeByteOff out (i * 2 + 1) (fromIntegral (word `quot` 256) :: Word8)
          loop source out (i + 1)
    quantize x
      | isNaN x = 0
      | x >= 1 = 32767
      | x <= -1 = -32767
      | x >= 0 = truncate (x * 32767 + 0.5)
      | otherwise = negate (truncate (negate x * 32767 + 0.5))
