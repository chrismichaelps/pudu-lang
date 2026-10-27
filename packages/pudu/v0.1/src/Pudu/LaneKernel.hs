{-| @Program.LaneKernel — names and signatures of the packed binary64 lane kernels

    One closed list read by the evaluator, the checker and name resolution. A
    signature is stated in a small vocabulary so the checker derives every type
    from it and no kernel's arity is written twice. -}
module Pudu.LaneKernel
  ( LaneKernel (..)
  , LaneType (..)
  , laneKernelName
  , laneKernelSignature
  , laneKernels
  ) where

import Data.Text (Text)

data LaneKernel
  = LaneFill
  | LaneRamp
  | LaneFromArray
  | LaneToArray
  | LaneCount
  | LaneGet
  | LaneSet
  | LaneSlice
  | LaneConcat
  | LaneAdd
  | LaneSub
  | LaneMul
  | LaneDiv
  | LaneMin
  | LaneMax
  | LaneAddScalar
  | LaneScale
  | LaneClamp
  | LaneAxpy
  | LaneFma
  | LaneAbs
  | LaneNegate
  | LaneSqrt
  | LaneFloor
  | LaneSum
  | LaneDot
  | LaneMinimum
  | LaneMaximum
  | LaneGather
  | LaneScatter
  | LaneAffine3
  | RasterFill
  | RasterTriangles
  deriving stock (Eq, Ord, Show, Enum, Bounded)

{-| Packed lanes as Bytes, a Float64, an Int, Array[Float64], Array[Int],
    an Option of one of those, two byte strings or three lanes. -}
data LaneType = LaneBytes | LaneFloat | LaneInt | LaneFloats | LaneInts | LaneOption !LaneType | LanePair | LaneTriple
  deriving stock (Eq, Show)

laneKernels :: [LaneKernel]
laneKernels = [minBound .. maxBound]

laneKernelName :: LaneKernel -> Text
laneKernelName kernel = case kernel of
  LaneFill -> "lanesFill"
  LaneRamp -> "lanesRamp"
  LaneFromArray -> "lanesFromArray"
  LaneToArray -> "lanesToArray"
  LaneCount -> "lanesCount"
  LaneGet -> "lanesGet"
  LaneSet -> "lanesSet"
  LaneSlice -> "lanesSlice"
  LaneConcat -> "lanesConcat"
  LaneAdd -> "lanesAdd"
  LaneSub -> "lanesSub"
  LaneMul -> "lanesMul"
  LaneDiv -> "lanesDiv"
  LaneMin -> "lanesMin"
  LaneMax -> "lanesMax"
  LaneAddScalar -> "lanesAddScalar"
  LaneScale -> "lanesScale"
  LaneClamp -> "lanesClamp"
  LaneAxpy -> "lanesAxpy"
  LaneFma -> "lanesFma"
  LaneAbs -> "lanesAbs"
  LaneNegate -> "lanesNegate"
  LaneSqrt -> "lanesSqrt"
  LaneFloor -> "lanesFloor"
  LaneSum -> "lanesSum"
  LaneDot -> "lanesDot"
  LaneMinimum -> "lanesMinimum"
  LaneMaximum -> "lanesMaximum"
  LaneGather -> "lanesGather"
  LaneScatter -> "lanesScatter"
  LaneAffine3 -> "lanesAffine3"
  RasterFill -> "rasterFill"
  RasterTriangles -> "rasterTriangles"

{-| Argument types and result type. -}
laneKernelSignature :: LaneKernel -> ([LaneType], LaneType)
laneKernelSignature kernel = case kernel of
  LaneFill -> ([LaneInt, LaneFloat], LaneOption LaneBytes)
  LaneRamp -> ([LaneInt, LaneFloat, LaneFloat], LaneOption LaneBytes)
  LaneFromArray -> ([LaneFloats], LaneBytes)
  LaneToArray -> ([LaneBytes], LaneFloats)
  LaneCount -> ([LaneBytes], LaneInt)
  LaneGet -> ([LaneBytes, LaneInt], LaneOption LaneFloat)
  LaneSet -> ([LaneBytes, LaneInt, LaneFloat], LaneOption LaneBytes)
  LaneSlice -> ([LaneBytes, LaneInt, LaneInt], LaneOption LaneBytes)
  LaneConcat -> ([LaneBytes, LaneBytes], LaneBytes)
  LaneAddScalar -> ([LaneBytes, LaneFloat], LaneBytes)
  LaneScale -> ([LaneBytes, LaneFloat], LaneBytes)
  LaneClamp -> ([LaneBytes, LaneFloat, LaneFloat], LaneBytes)
  LaneAxpy -> ([LaneBytes, LaneFloat, LaneBytes], LaneOption LaneBytes)
  LaneFma -> ([LaneBytes, LaneBytes, LaneBytes], LaneOption LaneBytes)
  LaneSum -> ([LaneBytes], LaneFloat)
  LaneDot -> ([LaneBytes, LaneBytes], LaneOption LaneFloat)
  LaneMinimum -> ([LaneBytes], LaneOption LaneFloat)
  LaneMaximum -> ([LaneBytes], LaneOption LaneFloat)
  LaneGather -> ([LaneBytes, LaneInts], LaneOption LaneBytes)
  LaneScatter -> ([LaneBytes, LaneInts, LaneBytes], LaneOption LaneBytes)
  LaneAffine3 -> ([LaneFloats, LaneBytes, LaneBytes, LaneBytes], LaneOption LaneTriple)
  RasterFill -> ([LaneInt, LaneFloat, LaneFloat, LaneFloat, LaneFloat], LaneOption LaneBytes)
  RasterTriangles ->
    ( [LaneBytes, LaneBytes, LaneInt, LaneInt, LaneBytes, LaneBytes, LaneBytes, LaneBytes, LaneBytes, LaneBytes]
    , LaneOption LanePair
    )
  _
    | kernel `elem` [LaneAdd, LaneSub, LaneMul, LaneDiv, LaneMin, LaneMax] ->
        ([LaneBytes, LaneBytes], LaneOption LaneBytes)
    | otherwise -> ([LaneBytes], LaneBytes)
