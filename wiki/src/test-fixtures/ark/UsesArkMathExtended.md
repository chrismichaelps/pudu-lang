---
type: module
path: "@root/test-fixtures/ark/UsesArkMathExtended.pudu"
fidelity: Active
aliases: [Ark Math Extended Fixture]
tags: [module, ark, test]
---
# Ark Math Extended Fixture

## Purpose

Exercises every function added in #666 with success, degenerate refusal and precision checks:
vector algebra and planar overflow-free length; singular and well-conditioned inverses checked
as products against identity; axis-angle, product order, slerp angle, matrix agreement and
transform composition/inversion; view placement, [0, 1] and reversed depth, orthographic
corners; every geometry query including frustum culling of points, spheres and boxes; sRGB
transfer, packing and NaN refusal; SplitMix64 reference outputs and ranges; noise lattice
zeros, repeatability, bounds and unrepresentable cells. Prints `ark math extended: ok`.

## Grill Log

- **Q:** Compare floating results with exact equality? **A:** Only where the operation is exact
  (endpoints, lattice zeros, reference integers); elsewhere within 1e-9.

## Referenced by

[[Ark Math Extended Gate]] · [[src/Ark/_MOC]]
