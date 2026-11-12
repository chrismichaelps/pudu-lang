---
type: module
path: "@root/src/Pudu/Backend/Runtime/Host/Raster.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Raster]
---
# Native Host Raster

The software render device's raster kernels in generated C: `rasterFill`,
`rasterTriangles`, `rasterPerspectiveTriangles`, `rasterTexturedTriangles` and
`rasterShadedTriangles` (#855), answering as `Pudu.Runtime.Raster`,
`Pudu.Runtime.Sampler` and `Pudu.Runtime.Shade` do.

## Interface

Runtime parts, each `(name, needs, lines)`:

| Part | C entry | Operands |
| --- | --- | --- |
| `host_raster_fill` | `pudu_host_raster_fill` | pixels, then red, green, blue and alpha |
| `host_raster_triangles` | `pudu_host_raster_triangles` | color, depth, width, cull, six vertex lanes |
| `host_raster_perspective` | `pudu_host_raster_perspective` | the same and a weight lane |
| `host_raster_textured` | `pudu_host_raster_textured` | the same, u and v lanes, texels, texel width, color space, filter |
| `host_raster_shaded` | `pudu_host_raster_shaded` | the perspective operands, normal and position lanes, a uniform lane |

`host_raster` holds the shared driver: vertex reading, culling, the top-left
fill rule, depth testing, sampling and shading.

## Governance

- Every refusal the interpreter answers with None answers None here, and every
  check runs before anything is allocated, so a refused call owns nothing.
- Each floating expression keeps the interpreter's operation order, grouping
  and comparisons: `min` and `max` keep their `<=` choice (which decides a
  signed zero), `x ^ 5` is `(x·x)·(x·x)·x`, rounding to a channel is to nearest
  even, and contraction into fused multiply-adds is off.
- `floor` and `ceiling` of a screen bound are clamped in floating point before
  they become an index, so no conversion leaves its range.
- The sRGB decode table is built per textured call from the same transfer
  function, so no shared mutable state crosses threads.

## Resolved Grill Log

- **Q:** One part per kernel or one entry with a mode? **A:** One per kernel.
  _Rationale:_ the kernels take different operand counts, and the lane kernel
  table passes a kernel's operands positionally. The shared driver keeps the
  logic in one place.
- **Q:** Guard the color target and the texels as whole lanes? **A:** No; they
  are RGBA bytes. The lane table skips exactly the positions the interpreter
  skips (the color target, and the texels of the textured kernel).

## Referenced by

[[Native Host Lanes]] · [[Compiler Lower Kernel Host]]
