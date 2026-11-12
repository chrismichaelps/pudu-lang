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
  , let (part, modes) = lanePart kernel
  , let name = laneKernelName kernel
        (operands, result) = laneKernelSignature kernel
        call = Call (KernelHost part) modes [0 .. length operands - 1]
        guards =
          [ Guard (Unless (Call (KernelHost "lanes_whole") [] [position])) "E7012" (name <> " needs lanes of whole binary64 values")
          | (position, LaneBytes) <- zip [0 ..] operands, position `notElem` byteTargets kernel ]
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

{-| Byte operands that are RGBA targets or texels rather than lanes, which
    the interpreter does not check for whole binary64 values. -}
byteTargets :: LaneKernel -> [Int]
byteTargets kernel = case kernel of
  RasterTriangles -> [0]
  RasterPerspectiveTriangles -> [0]
  RasterShadedTriangles -> [0]
  RasterTexturedTriangles -> [0, 13]
  _ -> []

{-| The runtime part behind a kernel and the integers that pick what it
    does. -}
lanePart :: LaneKernel -> (Text, [Int])
lanePart kernel = case kernel of
  LaneFill -> ("lanes_fill", [])
  LaneRamp -> ("lanes_ramp", [])
  LaneFromArray -> ("lanes_from_array", [0])
  LaneFromInts -> ("lanes_from_array", [1])
  LaneToArray -> ("lanes_to_array", [])
  LaneCount -> ("lanes_count", [])
  LaneGet -> ("lanes_get", [])
  LaneSet -> ("lanes_set", [])
  LaneSlice -> ("lanes_slice", [])
  LaneConcat -> ("lanes_concat", [])
  LaneAdd -> ("lanes_zip", [0])
  LaneSub -> ("lanes_zip", [1])
  LaneMul -> ("lanes_zip", [2])
  LaneDiv -> ("lanes_zip", [3])
  LaneMin -> ("lanes_zip", [4])
  LaneMax -> ("lanes_zip", [5])
  LaneAddScalar -> ("lanes_scalar", [0])
  LaneScale -> ("lanes_scalar", [1])
  LaneAbove -> ("lanes_scalar", [2])
  LaneClamp -> ("lanes_clamp", [])
  LaneAxpy -> ("lanes_axpy", [])
  LaneFma -> ("lanes_zip3", [0])
  LaneSelect -> ("lanes_zip3", [1])
  LaneAbs -> ("lanes_map", [0])
  LaneNegate -> ("lanes_map", [1])
  LaneSqrt -> ("lanes_map", [2])
  LaneFloor -> ("lanes_map", [3])
  LaneSum -> ("lanes_sum", [])
  LaneDot -> ("lanes_dot", [])
  LaneMinimum -> ("lanes_extreme", [0])
  LaneMaximum -> ("lanes_extreme", [1])
  LaneGather -> ("lanes_gather", [])
  LaneScatter -> ("lanes_scatter", [0])
  LaneScatterAdd -> ("lanes_scatter", [1])
  LaneAffine3 -> ("lanes_affine3", [])
  LaneInterleave -> ("lanes_interleave", [])
  LaneToPcm16 -> ("lanes_to_pcm16", [])
  LaneWhere -> ("lanes_where", [])
  LaneToInts -> ("lanes_to_ints", [])
  LaneOverlapPairs -> ("lanes_overlap_pairs", [])
  RasterFill -> ("raster_fill", [])
  RasterTriangles -> ("raster_triangles", [])
  RasterPerspectiveTriangles -> ("raster_perspective", [])
  RasterTexturedTriangles -> ("raster_textured", [])
  RasterShadedTriangles -> ("raster_shaded", [])
