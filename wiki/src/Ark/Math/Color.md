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

Binary64 throughout. Packing and 8-bit decoding have explicit Option boundaries; raw constructors
and unchecked channel operations retain IEEE values. `lerp` returns endpoints directly at t = 0
and t = 1, preserving signed zeros and NaN payloads. Within (0, 1), opposite-sign channels use
weighted endpoints to avoid an overflowing difference. Same-sign channels retain the fused
difference form, avoiding an overflowing rounded sum near the maximum finite value. Extrapolation retains the original
fused difference form and its ordinary IEEE behavior.
Depends on [[Std Math Float]] only, within layer zero.

## Grill Log

- **Q:** Use a difference even at exact endpoints? **A:** No; an unused opposite endpoint can
  overflow that difference or contaminate the selected endpoint. Return it directly.

- **Q:** Approximate sRGB with gamma 2.2? **A:** No; use the exact piecewise transfer.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math]] · [[Ark Math Extended Fixture]]
