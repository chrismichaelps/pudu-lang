---
type: module
path: "@root/lib/Ark/Math/Quat.pudu"
fidelity: Active
aliases: [Ark Quaternion]
tags: [module, ark, math]
---
# Ark Quaternion

## Purpose and interface

`Quat` holds x/y/z (vector part) and w (scalar part). `identity`, `quat`, `fromAxisAngle(axis,
radians) -> Option` (None for a zero or non-finite axis), `rotationX/Y/Z`, `multiply(left, right)`
applies right first, `conjugate`, `dot`, `lengthSquared`, `normalized -> Option`,
`inverse -> Option`, `rotate(q, v)`, `nlerp -> Option`, `slerp -> Option` (shortest arc, nlerp
when the arc is too small to divide by its sine), `toMat3`, `toMat4` and `angleBetween`.
`rotate` uses t = 2 (q.xyz × v), v' = v + w t + q.xyz × t: two cross products, no matrix.

Binary64 throughout with written operation order; degenerate input answers `None`, never NaN.
Depends on [[Ark Math]] and [[Std Math Float]] only, within layer zero.

## Grill Log

- **Q:** Normalize inside every operation? **A:** No; callers renormalize after accumulating
  products. `rotate` assumes unit input, documented, so the hot path stays two cross products.
- **Q:** Euler constructors? **A:** Only single-axis rotations; composition order stays explicit.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math]] · [[Ark Math Extended Fixture]]
