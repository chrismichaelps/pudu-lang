---
type: module
path: "@root/lib/Ark/Math/Transform.pudu"
fidelity: Active
aliases: [Ark Transform]
tags: [module, ark, math]
---
# Ark Transform

## Purpose and interface

`Transform` is translation, rotation (unit Quat) and per-axis scale applied as scale, then
rotation, then translation. `identity`, `transform`, `toMat4`, `transformPoint`,
`transformDirection` (no translation), `compose(parent, child)` and `inverse -> Option`.
`compose` is exact when the parent scale is uniform; otherwise the TRS form cannot hold the shear
and callers compose matrices. `inverse` answers `None` for zero or non-uniform scale.

Binary64 throughout with written operation order; degenerate input answers `None`, never NaN.
Depends on [[Ark Math]] and [[Std Math Float]] only, within layer zero.

## Grill Log

- **Q:** Hide shear by approximating non-uniform composition? **A:** No; state the exact domain
  and route general cases through [[Ark Matrix]] inverses.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math]] · [[Ark Math Extended Fixture]]
