---
type: module
path: "@root/lib/Ark/Math/Geometry.pudu"
fidelity: Active
aliases: [Ark Geometry]
tags: [module, ark, math]
---
# Ark Geometry

## Purpose and interface

`Aabb` (min/max), `Sphere`, `Ray` (unit direction), `Plane` (unit normal, distance) and
`Frustum` (six inward planes). Constructors: `aabb` orders corners, `aabbAround(center, half)`,
`sphere`, `ray -> Option` (None for zero direction), `plane(normal, point) -> Option`,
`frustum(viewProjection)` (plane extraction for [0, 1] depth). Queries: `center`, `halfExtents`,
`containsPoint`, `overlaps`, `merge`, `include`, `transformAabb(matrix, box)` (per-axis min/max of
products, no corner loop), `spheresOverlap`, `sphereOverlapsAabb`, `signedDistance`, `rayAabb`,
`raySphere`, `rayPlane`, `rayTriangle` (each `Option[Float64]` nearest non-negative distance),
`frustumContainsPoint`, `frustumOverlapsSphere` and `frustumOverlapsAabb` (positive-vertex test).

Binary64 throughout with written operation order; degenerate input answers `None`, never NaN.
Depends on [[Ark Math]] and [[Std Math Float]] only, within layer zero.

## Grill Log

- **Q:** Store frustum planes in an array? **A:** No; six named fields avoid indexing and bounds
  checks in the culling loop.
- **Q:** Divide by zero direction components in the slab test? **A:** IEEE infinities are the
  intended result; an origin exactly on a slab with zero direction is handled explicitly.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math]] · [[Ark Math Extended Fixture]]
