---
type: module
path: "@root/lib/Ark/Render/Mesh.pudu"
fidelity: Active
aliases: [Ark Mesh]
tags: [module, ark, render]
---
# Ark Mesh

## Purpose and interface

Non-indexed triangle lists in object space: position, normal and color lanes per vertex.
Primitive kinds are built by factories: the const `MESH_FACTORIES` table maps `"cube"`,
`"plane"`, `"pyramid"` and `"sphere"` (16 × 10 bands) to their factory, `primitive(kind, color) -> Option[Mesh]` looks a
kind up, and `cube`, `plane`, `pyramid` and `sphere` are the factories themselves. `fromTriangles(points,
color) -> Option[Mesh]` builds flat-shaded meshes from corner lists (None unless a multiple of
three), `triangleCount`, and `merge` concatenates meshes. Front faces wind counter-clockwise
seen from outside.

## Grill Log

- **Q:** Select primitives with a match over kind names? **A:** No; kinds map to factories in a
  const table, so adding a primitive is one factory and one row.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Render Fixture]]
