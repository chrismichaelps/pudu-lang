---
type: architecture
status: ACTIVE
aliases: [Ark Math Conventions]
tags: [architecture, ark, math]
---
# Ark Math Conventions

The initial engine math surface explicitly uses binary64. Vec3/Vec4 and Mat3/Mat4 contain fixed
immutable scalar records. This expresses source data shape without a native ABI, packed-layout,
SIMD or cross-target bitwise determinism promise. Keep IEEE expression order; no implicit fast math.

Matrices store columns named x/y/z/w and multiply column vectors. `multiply(left, right)` applies
right first, then left. Translation occupies Mat4's w column. A direction uses homogeneous w=0;
a point uses w=1. `transform4` returns the full homogeneous vector without implicit division.
Checked point projection divides by the computed w only when all four coordinates are finite
and w is nonzero, then refuses an overflowing quotient. It does not silently clamp, invent an
epsilon, or turn an invalid projection into the origin.

Mat3 is ordinary linear algebra. Camera handedness, clip-depth ranges, screen Y direction,
reverse depth and GPU upload format require their own explicit APIs. No projection-camera or
matrix inverse behavior is implied by the initial algebra. Existing Vec3 arithmetic is unchanged.

## Resolved Grill Log

- **Q:** Store rows while callers read columns? **A:** No; named columns and asymmetric fixtures
  make indexing and multiplication order observable.
- **Q:** Hide perspective division in every transform? **A:** No; transform4 keeps w explicit,
  while projectPoint exposes failure as Option.
- **Q:** Reject all small w values with an arbitrary epsilon? **A:** No; reject zero/non-finite
  values and unrepresentable results, retaining valid small-coordinate projections.

## Referenced by

[[Ark Engine]] · [[Ark Math]] · [[Ark Matrix]] · [[architecture/_MOC]]
