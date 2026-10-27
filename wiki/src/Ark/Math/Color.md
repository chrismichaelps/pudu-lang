---
type: module
path: "@root/lib/Ark/Math/Color.pudu"
fidelity: Active
aliases: [Ark Color]
tags: [module, ark, math]
---
# Ark Color

## Purpose and interface

`Rgba` holds linear binary64 channels. `rgba`, `opaque`, `lerp`, `multiply`, `premultiplied`,
`srgbToLinear` and `linearToSrgb` (exact IEC 61966-2-1 piecewise transfer), `fromSrgb8(r, g, b,
a)` and `toSrgb8 -> Option[UInt32]` packing R in the low byte (RGBA8 little-endian memory order).
Packing clamps to [0, 1] and rounds half away from zero; `None` for NaN channels.

Binary64 throughout with written operation order; degenerate input answers `None`, never NaN.
Depends on [[Ark Math]] and [[Std Math Float]] only, within layer zero.

## Grill Log

- **Q:** Approximate sRGB with gamma 2.2? **A:** No; use the exact piecewise transfer.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math]] · [[Ark Math Extended Fixture]]
