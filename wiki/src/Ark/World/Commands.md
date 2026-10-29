---
type: module
path: "@root/lib/Ark/World/Commands.pudu"
fidelity: Active
aliases: [Ark World Commands]
tags: [module, ark]
---
# Ark World Commands

## Purpose and interface

Deferred structural changes applied at one sync point. `Commands` queues spawns and despawns;
`commands()`, `spawn(commands, components, values)`, `despawn(commands, handle)`, `pending` and
`apply(world, commands) -> (World, Array[Option[Handle]])`. Apply removes every queued live entity
archetype by archetype with one `gather` per column and one location rebuild per archetype, then
appends queued spawns grouped by archetype with one concat per column. Stale despawns are
ignored; each spawn answers its handle or `None` when its components or values were invalid.

## Grill Log

- **Q:** Apply each command as it is queued? **A:** No; per-command structural edits copy columns
  per entity. Grouping makes the cost one pass per touched column per sync point.

## Referenced by

[[Ark World]] · [[src/Ark/_MOC]]
