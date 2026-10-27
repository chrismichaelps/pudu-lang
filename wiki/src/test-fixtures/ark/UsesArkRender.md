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

## Referenced by

[[Ark Render Gate]]
