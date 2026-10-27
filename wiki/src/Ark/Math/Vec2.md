---
type: module
path: "@root/lib/Ark/Math/Vec2.pudu"
fidelity: Active
aliases: [Ark Planar Vector]
tags: [module, ark, math]
---
# Ark Planar Vector

## Purpose and interface

`Vec2` holds binary64 x/y. `vec2`, `add`, `subtract`, `scale`, `multiply`, `negate`, `dot`,
`perpDot` (z of the 3D cross product), `perpendicular` (counter-clockwise quarter turn),
`lengthSquared`, `length -> Option`, `normalized -> Option`, `distance -> Option`, `lerp`,
`rotate(value, radians)`, `approxEqual(a, b, tolerance)` and `isFinite`.
`length` uses the overflow-free hypot kernel and answers `None` only when the true magnitude is
not representable or a component is not finite; `normalized` answers `None` for zero.

Binary64 throughout with written operation order; degenerate input answers `None`, never NaN.
Depends on [[Ark Math]] and [[Std Math Float]] only, within layer zero.

## Grill Log

- **Q:** Share function names with Vec3 in one module? **A:** No overloading exists; one module
  per vector width keeps call sites short (`Planar.add`) without suffix-mangled names.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math]] · [[Ark Math Extended Fixture]]
