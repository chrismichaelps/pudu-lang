{-| @Program.Eval.Builtin.Lanes — applies packed binary64 lane kernels to runtime values -}
module Pudu.Eval.Builtin.Lanes
  ( callLaneKernel
  ) where

import Data.Foldable (toList)
import qualified Data.Sequence as Seq
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..), intOf)
import Pudu.FloatKernel (FloatKernel (KernelFloor))
import Pudu.FloatLiteral (FloatWidth (Float64Width))
import Pudu.LaneKernel (LaneKernel (..), laneKernelName)
import Pudu.Runtime.FloatKernel (applyFloatUnary)
import qualified Pudu.Runtime.Broadphase as Broadphase
import qualified Pudu.Runtime.Lanes as Lanes
import qualified Pudu.Runtime.Raster as Raster
import Pudu.Source (Span)

{-| Apply a lane kernel. The checker admits only the kernel's signature, so a
    shape refusal is reached by an unchecked call or by lanes built from bytes
    that do not hold a whole number of binary64 values. -}
callLaneKernel :: Span -> LaneKernel -> [Value] -> Evaluator Value
callLaneKernel spanValue kernel values
  | not (all wholeLanes checked) =
      abortAt (Just spanValue) "E7012" (laneKernelName kernel <> " needs lanes of whole binary64 values") Nothing
  | otherwise = maybe refused pure (apply kernel values)
  where
    refused = abortAt (Just spanValue) "E7012" (laneKernelName kernel <> " got arguments outside its signature") Nothing
    wholeLanes (BytesValue bytes) = Lanes.laneWhole bytes
    wholeLanes _ = True
    checked = case kernel of
      RasterTriangles -> drop 1 values
      _ -> values

apply :: LaneKernel -> [Value] -> Maybe Value
apply kernel values = case (kernel, values) of
  (LaneFill, [IntValue _ count, FloatValue _ x]) -> Just (optionLanes (Lanes.laneFill (fromInteger count) x))
  (LaneRamp, [IntValue _ count, FloatValue _ start, FloatValue _ step]) ->
    Just (optionLanes (Lanes.laneRamp (fromInteger count) start step))
  (LaneFromArray, [ArrayValue items]) -> BytesValue . Lanes.laneFromList <$> traverse floatOf (toList items)
  (LaneToArray, [BytesValue a]) -> Just (ArrayValue (Seq.fromList (map float64 (Lanes.laneToList a))))
  (LaneCount, [BytesValue a]) -> Just (intOf (toInteger (Lanes.laneCount a)))
  (LaneGet, [BytesValue a, IntValue _ index]) -> Just (option float64 (index `within` Lanes.laneGet a))
  (LaneSet, [BytesValue a, IntValue _ index, FloatValue _ x]) ->
    Just (optionLanes (index `within` \i -> Lanes.laneSet a i x))
  (LaneSlice, [BytesValue a, IntValue _ start, IntValue _ count]) ->
    Just (optionLanes (bounded start >>= \s -> bounded count >>= Lanes.laneSlice a s))
  (LaneConcat, [BytesValue a, BytesValue b]) -> Just (BytesValue (Lanes.laneConcat a b))
  (LaneAdd, [BytesValue a, BytesValue b]) -> Just (optionLanes (Lanes.laneZip (+) a b))
  (LaneSub, [BytesValue a, BytesValue b]) -> Just (optionLanes (Lanes.laneZip (-) a b))
  (LaneMul, [BytesValue a, BytesValue b]) -> Just (optionLanes (Lanes.laneZip (*) a b))
  (LaneDiv, [BytesValue a, BytesValue b]) -> Just (optionLanes (Lanes.laneZip (/) a b))
  (LaneMin, [BytesValue a, BytesValue b]) -> Just (optionLanes (Lanes.laneZip smaller a b))
  (LaneMax, [BytesValue a, BytesValue b]) -> Just (optionLanes (Lanes.laneZip larger a b))
  (LaneAddScalar, [BytesValue a, FloatValue _ s]) -> Just (BytesValue (Lanes.laneMap (+ s) a))
  (LaneScale, [BytesValue a, FloatValue _ s]) -> Just (BytesValue (Lanes.laneMap (* s) a))
  (LaneClamp, [BytesValue a, FloatValue _ low, FloatValue _ high]) ->
    Just (BytesValue (Lanes.laneMap (\x -> if x < low then low else if x > high then high else x) a))
  (LaneAxpy, [BytesValue y, FloatValue _ factor, BytesValue x]) ->
    Just (optionLanes (Lanes.laneZip (\yi xi -> yi + factor * xi) y x))
  (LaneFma, [BytesValue a, BytesValue b, BytesValue c]) ->
    Just (optionLanes (Lanes.laneZip3 (\x y z -> x * y + z) a b c))
  (LaneAbs, [BytesValue a]) -> Just (BytesValue (Lanes.laneMap abs a))
  (LaneNegate, [BytesValue a]) -> Just (BytesValue (Lanes.laneMap negate a))
  (LaneSqrt, [BytesValue a]) -> Just (BytesValue (Lanes.laneMap sqrt a))
  (LaneFloor, [BytesValue a]) -> Just (BytesValue (Lanes.laneMap (applyFloatUnary KernelFloor) a))
  (LaneSum, [BytesValue a]) -> Just (float64 (Lanes.laneFold (+) 0 a))
  (LaneDot, [BytesValue a, BytesValue b]) ->
    Just (option float64 (Lanes.laneFold (+) 0 <$> Lanes.laneZip (*) a b))
  (LaneMinimum, [BytesValue a]) -> Just (option float64 (extreme smaller a))
  (LaneMaximum, [BytesValue a]) -> Just (option float64 (extreme larger a))
  (LaneGather, [BytesValue a, ArrayValue indices]) ->
    Just (optionLanes (traverse indexOf (toList indices) >>= Lanes.laneGather a))
  (LaneScatter, [BytesValue a, ArrayValue indices, BytesValue fresh]) ->
    Just (optionLanes (traverse indexOf (toList indices) >>= \is -> Lanes.laneScatter a is fresh))
  (LaneAffine3, [ArrayValue matrix, BytesValue xs, BytesValue ys, BytesValue zs]) -> do
    entries <- traverse floatOf (toList matrix)
    Just $ case Lanes.laneAffine3 entries xs ys zs of
      Just (rx, ry, rz) -> VariantValue "Some" [TupleValue [BytesValue rx, BytesValue ry, BytesValue rz]]
      Nothing -> VariantValue "None" []
  (LaneSelect, [BytesValue mask, BytesValue a, BytesValue b]) ->
    Just (optionLanes (Lanes.laneZip3 (\m x y -> if m > 0 then x else y) mask a b))
  (LaneAbove, [BytesValue a, FloatValue _ threshold]) ->
    Just (BytesValue (Lanes.laneMap (\x -> if x > threshold then 1 else 0) a))
  (LaneWhere, [BytesValue mask]) -> Just (intArray (Lanes.laneWhere mask))
  (LaneScatterAdd, [BytesValue a, ArrayValue indices, BytesValue fresh]) ->
    Just (optionLanes (traverse indexOf (toList indices) >>= \is -> Lanes.laneScatterAdd a is fresh))
  (LaneFromInts, [ArrayValue items]) -> do
    numbers <- traverse integerOf (toList items)
    Just (BytesValue (Lanes.laneFromList (map fromInteger numbers)))
  (LaneToInts, [BytesValue a]) ->
    Just (option (ArrayValue . Seq.fromList . map intOf) (traverse wholeOf (Lanes.laneToList a)))
  (LaneOverlapPairs, boxes) -> do
    lanes <- traverse bytesOf boxes
    Just $ case Broadphase.overlapPairs lanes of
      Just pairs -> VariantValue "Some" [intArray pairs]
      Nothing -> VariantValue "None" []
  (RasterFill, [IntValue _ pixels, FloatValue _ r, FloatValue _ g, FloatValue _ b, FloatValue _ a]) ->
    Just (optionLanes (bounded pixels >>= \count -> Raster.rasterFill count r g b a))
  (RasterTriangles, BytesValue color : BytesValue depth : IntValue _ width : IntValue _ cull : rest) -> do
    lanes <- traverse bytesOf rest
    Just $ case (cullOf cull, bounded width) of
      (Just culling, Just target) | Just (painted, depths) <- Raster.rasterTriangles color depth target culling lanes ->
        VariantValue "Some" [TupleValue [BytesValue painted, BytesValue depths]]
      _ -> VariantValue "None" []
  _ -> Nothing
  where
    bytesOf (BytesValue bytes) = Just bytes
    bytesOf _ = Nothing
    cullOf 0 = Just Raster.CullNone
    cullOf 1 = Just Raster.CullBack
    cullOf _ = Nothing
    within index use = bounded index >>= use
    extreme pick bytes = case Lanes.laneGet bytes 0 of
      Nothing -> Nothing
      Just first -> Just (Lanes.laneFold pick first bytes)

{-| NaN loses to any number, so a minimum or maximum ignores missing samples. -}
smaller :: Double -> Double -> Double
smaller x y
  | isNaN x = y
  | y < x = y
  | otherwise = x

larger :: Double -> Double -> Double
larger x y
  | isNaN x = y
  | y > x = y
  | otherwise = x

bounded :: Integer -> Maybe Int
bounded n
  | n < 0 || n > toInteger (maxBound :: Int) = Nothing
  | otherwise = Just (fromInteger n)

indexOf :: Value -> Maybe Int
indexOf (IntValue _ n) = bounded n
indexOf _ = Nothing

integerOf :: Value -> Maybe Integer
integerOf (IntValue _ n) = Just n
integerOf _ = Nothing

{-| An integral, finite value within the signed 64-bit range. -}
wholeOf :: Double -> Maybe Integer
wholeOf x
  | isNaN x || isInfinite x = Nothing
  | fromInteger whole /= x = Nothing
  | whole < -9223372036854775808 || whole > 9223372036854775807 = Nothing
  | otherwise = Just whole
  where
    whole = truncate x

intArray :: [Int] -> Value
intArray = ArrayValue . Seq.fromList . map (intOf . toInteger)

floatOf :: Value -> Maybe Double
floatOf (FloatValue _ x) = Just x
floatOf _ = Nothing

float64 :: Double -> Value
float64 = FloatValue Float64Width

optionLanes :: Maybe Lanes.Lanes -> Value
optionLanes = option BytesValue

option :: (a -> Value) -> Maybe a -> Value
option wrap = maybe (VariantValue "None" []) (\x -> VariantValue "Some" [wrap x])
