---
type: module
path: "@root/lib/Ark/Render/Device.pudu"
fidelity: Active
aliases: [Ark Render Device]
tags: [module, ark, render]
---
# Ark Render Device

## Purpose and interface

The software render device over [[Runtime Raster]]. `Target` owns an RGBA8 color buffer and a
Float64 depth lane of `width × height`. `target(width, height) -> Option`, `clear(target, color)`
(color fill plus depth 1.0), `draw(target, batch, cull) -> Option[Target]` rasterizes a
`ScreenBatch` (nine vertex lanes: screen x/y, divided depth, homogeneous w, r/g/b and texture
u/v; three vertices per triangle) in one native call. `drawTextured(target, batch, cull, texture,
filter)` multiplies the lit color by the [[Ark Texture Asset]] sampled at perspective-correct
u/v through [[Runtime Sampler]]; `filter` is `"nearest"` or `"bilinear"` and both the filter and
the texture's color space map to driver codes through const tables. Texels with alpha below one
half are cut out. `drawMaterial(target, batch, cull, material, filter)` scales lit color by an
[[Ark Asset Import]] material's tint and textures it with its albedo, `pixels`, and `snapshotPpm` encoding the color buffer as binary PPM for offscreen
inspection. `Cull` is `CullNone` or `CullBack`. A GPU device replaces this module behind the
same `Target`/`draw` contract.

## Grill Log

- **Q:** Sample textures in Pudu per pixel? **A:** No; sampling is per covered pixel, so it runs
  in the native driver. Unknown filters, spaces or texture storage answer None before drawing.

- **Q:** Discard w after projection? **A:** No; carry the `ws` lane through batching to the
  perspective raster entry. Invalid/non-positive/non-finite weights answer None. Manual
  screen-space batches use w = 1 for affine attributes. Depth remains affine in screen space.

- **Q:** One draw call per object? **A:** Allowed, but each call copies the targets; the
  pipeline concatenates batches so a frame is a few native calls.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Render Fixture]]
