---
type: module
path: "@root/lib/Ark/Assets/Texture.pudu"
fidelity: Active
aliases: [Ark Texture Asset]
tags: [module, ark, assets, texture]
---

# Ark Texture Asset

## Purpose and interface

Immutable CPU texture assets hold width, height, packed RGBA8 bytes (rows top to bottom) and an
explicit `linear` or `srgb` color space. `rgba8(width, height, pixels, space) -> Option[Texture]`
requires positive dimensions and exactly four bytes per texel. Validate byte-count quotients and
remainders before multiplication, so fabricated or oversized dimensions cannot overflow indexing.
Every public read revalidates record metadata because callers can construct records directly.

`texel(texture, x, y)` reads an in-bounds texel as straight-alpha linear [[Ark Color]]. sRGB
decoding affects RGB only. `nearest` and `bilinear` accept finite normalized UV, clamping outside
[0, 1] to edge texels. Texel centers are (i + 0.5) / extent. Bilinear filtering decodes before
blending, premultiplies RGB by alpha, interpolates, then unpremultiplies; zero alpha returns
transparent black. This avoids gamma-darkened interpolation and transparent-color fringes.

`sample(texture, sampler, u, v)` selects the `nearest` or `bilinear` function through a const
factory table; color-space decoders also use a const table. Unknown names, malformed records,
non-finite UV and out-of-bounds texel reads answer None. No filesystem or GPU resource is owned
here; import/cook, residency and hot reload compose above this checked CPU asset representation.

## Resolved Grill Log

- **Q:** Filter encoded sRGB bytes directly? **A:** No; decode each texel before interpolation.
- **Q:** Interpolate transparent RGB as straight alpha? **A:** No; premultiplied filtering removes
  invisible-color fringes, then returns the library's straight-alpha representation.
- **Q:** Trust a factory-produced public record? **A:** No; sampling validates dimensions and
  storage again, using division checks before potentially overflowing index products.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Texture Fixture]] · [[Ark Assets Gate]] · [[Ark Texture Delivery]]
