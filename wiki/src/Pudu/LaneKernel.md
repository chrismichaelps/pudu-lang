---
type: module
path: "@root/src/Pudu/LaneKernel.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, performance, lanes]
aliases: [Lane Kernel Identity]
---

# Lane Kernel Identity

## Purpose and interface

States every packed binary64 lane kernel, its prelude name (`lanes` followed by the operation)
and its signature in a closed vocabulary: `LaneBytes`, `LaneFloat`, `LaneInt`, `LaneFloats`
(Array[Float64]), `LaneInts` (Array[Int]), `LaneOption t`, `LanePair` (two byte strings) and `LaneTriple` (three lanes). `rasterFill` and
`rasterTriangles` share the family; [[Runtime Raster]] implements them. `lanesSelect`, `lanesAbove`, `lanesWhere`, `lanesScatterAdd`, `lanesFromInts` and `lanesToInts`
are the data-parallel control set (#684). `lanesOverlapPairs` answers
`Option[Array[Int]]`; [[Runtime Broadphase]] implements it.
[[Type Check Prelude]] derives each scheme from the signature, [[Eval Install]] binds each name
and [[Semantic Prelude]] lists them, so no list can drift. Depends only on `Data.Text`.

## Grill Log

- **Q:** Return PCM as lanes? **A:** No; `LaneToPcm16` (`lanesToPcm16`) answers plain bytes, the
  device format, while `LaneInterleave` (`lanesInterleave`) answers optional lanes.
- **Q:** Pass texture state as one record? **A:** No; kernel arguments are positional values.
  `RasterTexturedTriangles` (`rasterTexturedTriangles`) appends u and v lanes after w, then texel
  bytes, texture width, color-space code and filter code.
- **Q:** Preserve the affine raster entry? **A:** Yes; add `RasterPerspectiveTriangles` named
  `rasterPerspectiveTriangles`, appending one homogeneous-w byte lane after b, with the same
  optional color/depth pair. The existing name, arity and output remain unchanged. Derived
  registration keeps checker, resolution and evaluation aligned.

- **Q:** One builtin per kernel? **A:** One `LaneKernelBuiltin` carrying the enumeration, like
  [[Float Kernel Identity]], so dispatch is a single case and signatures are stated once.

## Referenced by

[[Runtime Lanes]] · [[Eval Builtin Lanes]] · [[Std Lanes]]
