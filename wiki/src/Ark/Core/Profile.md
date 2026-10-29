---
type: module
path: "@root/lib/Ark/Core/Profile.pudu"
fidelity: Active
aliases: [Ark Profile]
tags: [module, ark]
---
# Ark Profile

## Purpose and interface

Named nanosecond scopes. `Profile` maps a scope name to its sample count, total, minimum and
maximum. `empty()`, `now()` (monotonic nanoseconds), `record(profile, name, startedAt)`
records `now() - startedAt`, `sample(profile, name, nanos)` records a measured duration,
`stats(profile, name) -> Option[Stats]`, `names` (sorted) and `reset`. Recording never
allocates per sample beyond the map update.

## Grill Log

- **Q:** Use the millisecond clock? **A:** No; a frame is a few milliseconds and a native kernel a
  fraction of one. The nanosecond clock (#670) is required.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Engine]]
