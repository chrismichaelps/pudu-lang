---
type: module
path: "@root/lib/Ark/Physics/Query.pudu"
fidelity: Active
aliases: [Ark Physics Query]
tags: [module, ark, physics]
---
# Ark Physics Query

## Purpose and interface

`raycast(bodies, ray, maxDistance) -> Option[Hit]` answers the nearest body a ray reaches
within the distance, using [[Ark Geometry]] sphere and box tests; `Hit` has the entity, distance
and point. `overlapsPoint(bodies, point) -> Array[Handle]` lists bodies containing a point.

## Grill Log

- **Q:** Test static planes in raycasts? **A:** Not yet; planes are solver boundaries, and
  queries cover bodies, which carry entities.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Physics Fixture]]
