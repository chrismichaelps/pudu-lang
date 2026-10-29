---
type: module
path: "@root/lib/Ark/Math/Matrix.pudu"
fidelity: Active
aliases: [Ark Matrix]
tags: [module, ark, math]
---
# Ark Matrix

## Purpose and interface

Pure fixed-record algebra under [[Ark Math Conventions]]. Mat3 has Vec3 columns x/y/z; Mat4
has Vec4 columns x/y/z/w. `columns3/4` construct them; `identity3/4` construct identities.
`transform3/4` multiply column vectors with written left-associated scalar sums. `multiply3/4`
transform each right column through the left matrix. `transpose3/4` exchange rows and columns.
`translation` and `scaling` construct affine Mat4 values. `projectPoint` transforms (x,y,z,1),
refuses zero/non-finite w or other coordinates, divides by w, and refuses non-finite quotients.

Inverses (#666): `determinant3` is the column triple product; `inverse3 -> Option` builds rows
from column cross products. `determinant4` and `inverse4 -> Option` share twelve two-by-two
minors of the upper and lower row pairs, so the inverse costs one minor pass and one
reciprocal. Singular, non-finite determinants or any non-finite entry answer `None`.
`affine(linear, offset)`, `linearPart`, `transformPoint` (w = 1, no division) and
`transformDirection` (w = 0) serve transform and culling code.

## Dependencies and algorithm

Imports [[Ark Math]] for Vec3/Vec4 and [[Std Math Float]] for finite checks. No arrays, host
matrix kernels, FFI, or C11 emission. Algebra admits ordinary IEEE non-finite results; only
projectPoint is a checked boundary returning Option[Vec3]. Native execution remains separate.

## Resolved Grill Log

- **Q:** Implement multiply through arrays and dynamic indices? **A:** No; fixed columns directly
  express the sixteen scalar products and avoid a collection allocation in source.
- **Q:** Treat zero w as a point at the origin? **A:** No; it is absence of a finite projection.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math Conventions]] · [[Ark Matrix Fixture]] · [[Ark Matrix Delivery]]
