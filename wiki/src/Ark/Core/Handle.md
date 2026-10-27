---
type: module
path: "@root/lib/Ark/Core/Handle.pudu"
fidelity: Active
aliases: [Ark Handle]
tags: [module, ark]
---
# Ark Handle

## Purpose and interface

Generational handles for engine-owned slots. `Handle` is an index and a generation;
`HandlePool` holds one generation per index, a free-index stack and the live count. `empty`,
`allocate -> (HandlePool, Handle)` (reuses the most recently freed index, else appends),
`release -> Option[HandlePool]` (None for a stale or unknown handle), `isAlive`, `liveCount`
and `capacity`. Release increments the slot's generation, so every handle issued before it
becomes stale before the index is reused.

## Grill Log

- **Q:** Reuse indices first-in first-out to delay ABA? **A:** No; the generation already
  rejects every stale handle, and last-in reuse keeps recently touched slots warm.

## Referenced by

[[src/Ark/_MOC]] · [[Ark World]]
