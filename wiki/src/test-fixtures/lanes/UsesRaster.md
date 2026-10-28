---
type: module
path: "@root/test-fixtures/lanes/UsesRaster.pudu"
fidelity: Active
aliases: [Raster Fixture]
tags: [module, test, render]
---
# Raster Fixture

Golden pixels for [[Runtime Raster]]: fill quantization; two triangles sharing a diagonal
covering an 8×8 target exactly once; barycentric color at a pixel center; depth order
independent of submission order; back-face culling; out-of-range depth skipped; bounds clipped
to the target; refusals for partial triangles, lane mismatch, unknown cull and a mis-sized
target. The perspective entry checks perspective-correct color at a pixel center, equal
weights matching affine interpolation, uniformly scaled subnormal weights keeping identical
pixels, and refusal of zero, negative, NaN, infinite and mis-sized weight lanes.
The textured entry checks nearest texels, lit-color modulation, bilinear clamping across texel
centers, sRGB decoding, cutout fragments that write neither color nor depth, w-scale invariance
and refusal of malformed texture storage, unknown codes and mismatched lanes.
Run by [[Lanes Gate]]. Prints `raster: ok`.

## Referenced by

[[Lanes Gate]]
