---
type: module
path: "@root/test-fixtures/ark/UsesArkPerspective.pudu"
fidelity: Active
aliases: [Ark Perspective Fixture]
tags: [module, ark, render, test]
---

# Ark Perspective Fixture

## Purpose and interface

Rasterize a triangle with analytic barycentric coordinates and unequal homogeneous w. Require
perspective-correct RGBA pixels and unchanged affine depth. Equal w retains affine attributes;
uniformly tiny, subnormal and huge w scales preserve pixels. Refuse mismatched, zero, negative,
NaN and infinite w. An odd-pixel target verifies that RGBA8 storage is not mistaken for a
binary64 lane. Successful execution prints `ark perspective: ok` and returns zero.

Unequal vertex depths distinguish affine screen-depth interpolation from an incorrect perspective
division of depth. A representable edge sample whose normalized denominator underflows to zero
must retain both its clear color and clear depth, while an interior sample still draws.

## Resolved Grill Log

- **Q:** Compare two copies of the raster algorithm? **A:** No; use fixed analytic fractions
  at known pixel centers and public device calls.
- **Q:** Test only ordinary w? **A:** No; scale invariance catches unnecessary reciprocals and
  preserves representable interpolation even when 1/w would overflow.

## Referenced by

[[Ark Render Device]] · [[Ark Render Gate]] · [[src/Ark/_MOC]]
