---
type: module
path: "@root/lib/Ark/Render/Mesh.pudu"
fidelity: Active
aliases: [Ark Mesh]
tags: [module, ark, render]
---
# Ark Mesh

## Purpose and interface

Non-indexed triangle lists in object space: position, normal, color and texture u/v lanes per
vertex, with v growing down the texture. Cube, plane and pyramid base faces map the whole texture
upright on each face; pyramid sides map a centered apex; the sphere maps longitude to u and
latitude from the top pole to v. `fromTriangles` leaves coordinates zero and
`withCoordinates(mesh, u, v)` replaces them, refusing counts that differ from the vertex count.
Primitive kinds are built by factories: the const `MESH_FACTORIES` table maps `"cube"`,
`"plane"`, `"pyramid"` and `"sphere"` (16 × 10 bands) to their factory, `primitive(kind, color) -> Option[Mesh]` looks a
kind up, and `cube`, `plane`, `pyramid` and `sphere` are the factories themselves. `fromTriangles(points,
color) -> Option[Mesh]` builds flat-shaded meshes from corner lists (None unless a multiple of
three), `triangleCount`, and `merge` concatenates meshes. Front faces wind counter-clockwise
seen from outside.

## Grill Log

- **Q:** Keep coordinates optional per mesh? **A:** No; every mesh carries u/v lanes so batches
  concatenate without shape checks. Untextured draws ignore them at the cost of two lanes.

- **Q:** Select primitives with a match over kind names? **A:** No; kinds map to factories in a
  const table, so adding a primitive is one factory and one row.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Render Fixture]]
