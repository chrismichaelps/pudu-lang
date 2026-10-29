---
type: module
path: "@root/lib/Ark/Math.pudu"
fidelity: Active
aliases: [Ark Math]
tags: [module, ark, math]
---
# Ark Math

## Purpose and interface

Layer-zero pure geometry for [[Ark Engine]]. `Vec3` has immutable x/y/z Float64 fields.
`vec3`, `add`, `subtract`, `scale`, `dot`, and right-handed `cross` operate on values,
preserving written IEEE arithmetic order. Public arithmetic admits IEEE non-finite values;
it does not silently clamp. `isFinite` tests every component.

`length` returns Option[Float64]: Some(0) for zero; None for non-finite components or an
unrepresentable magnitude. `normalized` returns Option[Vec3]: None for zero/non-finite
inputs, otherwise a finite unit direction even if the original magnitude would overflow.

## Algorithm and dependencies

Depends only on [[Std Math Float]] as a lower-level numeric utility. Use the maximum absolute
component as a scale, divide each component by it, then take sqrt of the sum of scaled squares.
For a nonzero finite input that sum lies in [1,3]. Length multiplies the scaled magnitude by the
scale and checks representability; normalization divides the scaled vector by the scaled magnitude.
This avoids premature overflow/underflow and confines the existing sqrt iteration to a bounded
domain. Scalar records allocate no arrays in source; no native layout or SIMD claim follows.

## Resolved Grill Log

- **Q:** Normalize by first computing length? **A:** No; a finite vector can have an overflowing
  length and still have a representable unit direction.
- **Q:** Hide NaN/infinity in a zero fallback? **A:** No; return None at checked operations.
- **Q:** Reject all tiny vectors with an epsilon? **A:** No; scale first, retaining subnormal directions.
- **Q:** Promise bitwise cross-target determinism? **A:** No; binary64 and written operation order only.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Engine]] · [[Ark Math Fixture]] · [[Ark Foundation Delivery]]
