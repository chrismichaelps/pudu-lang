---
type: module
path: "@root/src/Pudu/Runtime/Sampler.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, performance, render]
aliases: [Runtime Sampler]
---

# Runtime Sampler

## Purpose and interface

Per-pixel texture sampling for [[Runtime Raster]]'s textured entry. `sampler(texels, width,
space, filter)` validates RGBA8 storage (positive width, a whole number of rows, at least one
row) plus a color-space code (0 linear, 1 sRGB) and a filter code (0 nearest, 1 bilinear), or
answers `Nothing`. `withSampler` pins the texel bytes for the duration of one raster call, and
`sample` returns straight-alpha linear RGBA at a finite normalized UV.

- UV clamps to [0, 1] (clamp-to-edge). Nearest selects floor(u · width), bounded to the last
  texel; bilinear centers texels at (i + 0.5) / width and filters four bounded neighbours.
- sRGB channels decode through a 256-entry table computed once with the exact piecewise
  transfer; alpha is always linear.
- Bilinear filtering premultiplies before interpolating and divides afterwards, so transparent
  texels contribute no color fringe; zero filtered alpha answers transparent black.
- These rules match `Ark.Assets.Texture` sampling, which remains the checked Pudu reference.

## Grill Log

- **Q:** Decode sRGB with pow per fetch? **A:** No; a bilinear fetch decodes twelve channels.
  The 256-entry table makes decoding a load and produces the same values as the formula.
- **Q:** Sample in Pudu and pass colors to the rasterizer? **A:** No; sampling is per pixel, not
  per vertex, so it belongs with coverage in the native driver.

## Referenced by

[[Runtime Raster]] · [[Raster Fixture]]
