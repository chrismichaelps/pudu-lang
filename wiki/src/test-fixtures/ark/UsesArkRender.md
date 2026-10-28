---
type: module
path: "@root/test-fixtures/ark/UsesArkRender.pudu"
fidelity: Active
aliases: [Ark Render Fixture]
tags: [module, ark, test, render]
---
# Ark Render Fixture

Checks [[Ark Mesh]] factories (including an unknown kind), face orientation and refusals;
[[Ark Render Pipeline]] and [[Ark Render Device]] by pixel: the clear color, a fully lit front
face at the center, background outside, written depth, a rotated cube, Lambert shading of a
slanted plane within its expected band, geometry behind the camera skipped, the nearer of two
cubes winning in one draw, and the snapshot size; [[Ark Frame Graph]] culling, order,
lifetimes, execution and its three refusals. Prints `ark render: ok`.

Normal-transform regressions compare lit vertex intensity with a geometric normal built from
transformed triangle edges under non-uniform scale and shear. Singular transforms, non-positive
target dimensions and NaN ambient light are refused.
An asymmetric model/projection case with nonsymmetric off-diagonal linear coefficients compares projected lane coordinates and depth with scalar
homogeneous matrix multiplication, catching column layout, translation and w-row mistakes.

## Resolved Grill Log

- **Q:** Derive expected lighting with another inverse transpose? **A:** No; the test constructs
  a geometric normal from transformed tangents, providing an independent result.

## Referenced by

[[Ark Render Gate]]
