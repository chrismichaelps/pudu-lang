---
type: module
path: "@root/lib/Ark/World.pudu"
fidelity: Active
aliases: [Ark World]
tags: [module, ark]
---
# Ark World

## Purpose and interface

Archetype entity storage on [[Std Lanes]]. A registered component has a name and a count of
Float64 fields; a zero-field component is a tag. Entities with the same component set share an
archetype whose every component field is one lane column, so a system transforms all of them
with whole-lane kernels. `World` holds the schema, archetypes, an archetype index keyed by the
sorted component set, entity locations and an [[Ark Handle]] pool.

`empty`, `register(world, name, fields) -> Option` (None for a clash or negative count),
`create(world, components, values) -> Option[(World, Handle)]` with values in the given
component order, `createBatch(world, components, count, columns)` (one lane per field in the
given order, one concat per column), `destroy -> Option`, `destroyAll` (one compaction per touched archetype), `isAlive`, `has`, `get -> Option[Array]`,
`set -> Option`, `insert` and `remove` (move an entity between archetypes), `liveCount`.
Systems: `query(world, all, none) -> Array[Int]` archetype indices; `viewOf(world, archetype)`, `rowCount`;
`columnOf(view, component, field) -> Option[Lanes]`, `write(view, component, field, lanes) ->
Option[View]` (refuses a length change) and `commit(world, view) -> Option[World]`;
`each(world, all, none, system)` runs a `fn(View) -> Option[View]` over every match.
Unknown components, stale handles and value-count mismatches answer `None`.

## Grill Log

- **Q:** Store components as records per entity? **A:** No; per-entity records make every system
  an interpreted loop. Columns of lanes make a system a handful of native passes.
- **Q:** Remove rows by swapping the last row in? **A:** Immediate `destroy` does, touching two
  rows per column. Batched removal in [[Ark World Commands]] compacts once with `gather`.
- **Q:** Non-float component data? **A:** Tags and Float64 fields now; integer and reference
  columns need typed lanes and are a later slice, not an encoding inside floats.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Engine]] · [[Ark World Commands]]
