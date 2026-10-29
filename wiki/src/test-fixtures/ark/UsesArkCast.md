---
type: module
path: "@root/test-fixtures/ark/UsesArkCast.pudu"
fidelity: Active
aliases: [Ark Cast Fixture]
tags: [module, ark, physics, test]
---
# Ark Cast Fixture

Check [[Ark Segment Box Distance]] witnesses against face/edge/interior analytic values and an
independently sampled upper bound. Exercise [[Ark Capsule Box Cast]] with high-speed face hits,
rounded edge/corner hits and misses, sphere degeneration, arbitrary capsule orientation, touching
and separating motion, initial overlap, zero motion, numeric rejection and explicit exhaustion.
Cover tilted segment-interior and end-of-interval contacts, grazing edges, and distance scales
from 1e-200 through 1e200. Check fractions, normals, witness positions and exact output `ark cast: ok`.

## Resolved Grill Log

- **Q:** Only check whether a hit exists? **A:** No; analytic fractions and witnesses detect wrong geometry.
- **Q:** Let failed convergence pass as clear space? **A:** No; assert its distinct error variant.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Cast Gate]] · [[Ark Cast Delivery]]
