{-| @Compiler.Lower.Kernel.Lanes — the packed binary64 lane kernels. Each
    signature is read from the one list the checker reads, so a kernel's
    operands are written once. Byte operands are checked for whole lanes
    after every operand has run, as the interpreter checks them. -}
module Pudu.Compiler.Lower.Kernel.Lanes (lanePrimitives) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Kernel.Shape
import Pudu.Core
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.LaneKernel (LaneKernel (..), LaneType (..), laneKernelName, laneKernelSignature, laneKernels)

lanePrimitives :: [(Text, Primitive)]
lanePrimitives =
  [ (name, Primitive (map formed operands) (formed result) guards answer)
  | kernel <- laneKernels
  , Just (part, modes) <- [lanePart kernel]
  , let name = laneKernelName kernel
        (operands, result) = laneKernelSignature kernel
        call = Call (KernelHost part) modes [0 .. length operands - 1]
        guards =
          [ Guard (Unless (Call (KernelHost "lanes_whole") [] [position])) "E7012" (name <> " needs lanes of whole binary64 values")
          | (position, LaneBytes) <- zip [0 ..] operands ]
        answer = case result of
          LaneOption _ -> Absent call
          _ -> Plain call
  ]

formed :: LaneType -> CoreType
formed kind = case kind of
  LaneBytes -> CoreBytesType
  LaneFloat -> CoreFloatType Float64Width
  LaneInt -> CoreIntegerType PlatformSigned
  LaneFloats -> CoreArrayType (CoreFloatType Float64Width)
  LaneInts -> CoreArrayType (CoreIntegerType PlatformSigned)
  LaneOption held -> CoreSumType "Option" [formed held]
  LanePair -> CoreTupleType [CoreBytesType, CoreBytesType]
  LaneTriple -> CoreTupleType [CoreBytesType, CoreBytesType, CoreBytesType]

{-| The runtime part behind a kernel and the integers that pick what it
    does. The raster and broad-phase kernels have no native part. -}
lanePart :: LaneKernel -> Maybe (Text, [Int])
lanePart kernel = case kernel of
  LaneFill -> Just ("lanes_fill", [])
  LaneRamp -> Just ("lanes_ramp", [])
  LaneFromArray -> Just ("lanes_from_array", [0])
  LaneFromInts -> Just ("lanes_from_array", [1])
  LaneToArray -> Just ("lanes_to_array", [])
  LaneCount -> Just ("lanes_count", [])
  LaneGet -> Just ("lanes_get", [])
  LaneSet -> Just ("lanes_set", [])
  LaneSlice -> Just ("lanes_slice", [])
  LaneConcat -> Just ("lanes_concat", [])
  LaneAdd -> Just ("lanes_zip", [0])
  LaneSub -> Just ("lanes_zip", [1])
  LaneMul -> Just ("lanes_zip", [2])
  LaneDiv -> Just ("lanes_zip", [3])
  LaneMin -> Just ("lanes_zip", [4])
  LaneMax -> Just ("lanes_zip", [5])
  LaneAddScalar -> Just ("lanes_scalar", [0])
  LaneScale -> Just ("lanes_scalar", [1])
  LaneAbove -> Just ("lanes_scalar", [2])
  LaneClamp -> Just ("lanes_clamp", [])
  LaneAxpy -> Just ("lanes_axpy", [])
  LaneFma -> Just ("lanes_zip3", [0])
  LaneSelect -> Just ("lanes_zip3", [1])
  LaneAbs -> Just ("lanes_map", [0])
  LaneNegate -> Just ("lanes_map", [1])
  LaneSqrt -> Just ("lanes_map", [2])
  LaneFloor -> Just ("lanes_map", [3])
  LaneSum -> Just ("lanes_sum", [])
  LaneDot -> Just ("lanes_dot", [])
  LaneMinimum -> Just ("lanes_extreme", [0])
  LaneMaximum -> Just ("lanes_extreme", [1])
  LaneGather -> Just ("lanes_gather", [])
  LaneScatter -> Just ("lanes_scatter", [0])
  LaneScatterAdd -> Just ("lanes_scatter", [1])
  LaneAffine3 -> Just ("lanes_affine3", [])
  LaneInterleave -> Just ("lanes_interleave", [])
  LaneToPcm16 -> Just ("lanes_to_pcm16", [])
  LaneWhere -> Just ("lanes_where", [])
  LaneToInts -> Just ("lanes_to_ints", [])
  _ -> Nothing
