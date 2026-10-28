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
`ScreenBatch` (seven vertex lanes: screen x/y, divided depth, homogeneous w and r/g/b;
three vertices per triangle) in one
native call, `pixels`, and `snapshotPpm` encoding the color buffer as binary PPM for offscreen
inspection. `Cull` is `CullNone` or `CullBack`. A GPU device replaces this module behind the
same `Target`/`draw` contract.

## Grill Log

- **Q:** Discard w after projection? **A:** No; carry the `ws` lane through batching to the
  perspective raster entry. Invalid/non-positive/non-finite weights answer None. Manual
  screen-space batches use w = 1 for affine attributes. Depth remains affine in screen space.

- **Q:** One draw call per object? **A:** Allowed, but each call copies the targets; the
  pipeline concatenates batches so a frame is a few native calls.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Render Fixture]]
