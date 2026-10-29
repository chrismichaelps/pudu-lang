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

The software render device's native work, exposed through [[Lane Kernel Identity]].
`rasterFill(pixels, r, g, b, a)` makes an RGBA8 target of one color. `rasterTriangles(color,
depth, width, cull, xs, ys, zs, rs, gs, bs)` copies the color target and the Float64 depth lane
once, then rasterizes every triangle (three vertices each) in place and answers both targets.

- Pixel centers are sampled; a pixel on an edge belongs to a triangle only for a top or left
  edge, so triangles sharing an edge cover every pixel exactly once.
- Depth is interpolated linearly in screen space and tested less-than. The existing affine
  entry preserves its color interpolation and output. `rasterPerspectiveTriangles` appends a
  homogeneous-w lane and interpolates color as sum(lambda * color / w) / sum(lambda / w).
  Normalize weights per triangle as min(w) / w, avoiding reciprocal overflow for tiny positive w.
- `rasterTexturedTriangles` appends u and v lanes after w, then the texture's RGBA8 bytes, width,
  color-space code and filter code checked by [[Runtime Sampler]]. UV is interpolated
  perspective-correctly like color; the lit color is multiplied by the sampled texel. A texel
  whose alpha is below one half is a cutout: neither depth nor color is written.
- `rasterShadedTriangles` takes perspective lanes with unlit base colors, then world normal and
  position lanes and a uniform lane; [[Runtime Shade]] lights every pixel from its
  perspective-correct normal and position.
- Channels clamp to [0, 1] and round to eight bits; alpha is written opaque.
- Cull 0 keeps both faces, 1 drops faces clockwise in device coordinates. Vertices with depth
  outside [0, 1] or non-finite positions skip their triangle; near-plane clipping belongs to the
  pipeline.
- Mismatched lane counts, a vertex count not divisible by three, a target that disagrees with
  the width, or an unknown cull answer `None`.

## Grill Log

- **Q:** Blend translucent texels? **A:** No; blending needs sorted submission the device does not
  promise. Alpha below one half cuts the fragment out before its depth write, so cutout foliage
  and decals depth-test correctly in any order.

- **Q:** Perspective-correct the already divided depth? **A:** No; z/w is affine in screen
  space. Only vertex attributes use reciprocal-w interpolation.
- **Q:** Form raw reciprocals of w? **A:** No; the common scale cancels, so normalize with min(w)
  first and keep all weights at most one. Zero, negative and non-finite w are refused before
  copying targets. Invalid interpolated weights skip fragments before depth writes.

- **Q:** Rasterize in Pudu? **A:** No; interpreted per-pixel work costs about a microsecond a
  pixel. Transformation, culling and shading inputs stay in Pudu as lane kernels; only coverage
  and depth testing run natively, like a device driver.
- **Q:** One call per triangle? **A:** No; each call copies its targets, so the device batches
  every triangle of a draw into one call.

## Referenced by

[[Eval Builtin Lanes]] · [[Runtime Sampler]] · [[Raster Fixture]] · [[Raster Delivery]]
