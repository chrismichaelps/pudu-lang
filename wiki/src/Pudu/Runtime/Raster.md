---
type: module
path: "@root/src/Pudu/Runtime/Raster.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, performance, render]
aliases: [Runtime Raster]
---

# Runtime Raster

## Purpose and interface

The software render device's native work, exposed as two [[Lane Kernel Identity]] entries.
`rasterFill(pixels, r, g, b, a)` makes an RGBA8 target of one color. `rasterTriangles(color,
depth, width, cull, xs, ys, zs, rs, gs, bs)` copies the color target and the Float64 depth lane
once, then rasterizes every triangle (three vertices each) in place and answers both targets.

- Pixel centers are sampled; a pixel on an edge belongs to a triangle only for a top or left
  edge, so triangles sharing an edge cover every pixel exactly once.
- Depth and color are interpolated linearly in screen space; depth is tested less-than and
  written. Color interpolation is affine, not perspective-corrected.
- Channels clamp to [0, 1] and round to eight bits; alpha is written opaque.
- Cull 0 keeps both faces, 1 drops faces clockwise in device coordinates. Vertices with depth
  outside [0, 1] or non-finite positions skip their triangle; near-plane clipping belongs to the
  pipeline.
- Mismatched lane counts, a vertex count not divisible by three, a target that disagrees with
  the width, or an unknown cull answer `None`.

## Grill Log

- **Q:** Rasterize in Pudu? **A:** No; interpreted per-pixel work costs about a microsecond a
  pixel. Transformation, culling and shading inputs stay in Pudu as lane kernels; only coverage
  and depth testing run natively, like a device driver.
- **Q:** One call per triangle? **A:** No; each call copies its targets, so the device batches
  every triangle of a draw into one call.

## Referenced by

[[Eval Builtin Lanes]] · [[Raster Fixture]] · [[Raster Delivery]]
