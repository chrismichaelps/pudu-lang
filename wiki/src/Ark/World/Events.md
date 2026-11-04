---
type: module
path: "@root/lib/Ark/World/Events.pudu"
fidelity: Active
aliases: [Ark Events]
tags: [module, ark, world]
---
# Ark Events

## Purpose and interface

Typed double-buffered event queues. `Events[T]` holds the previous and current frame's events
and the id of the oldest kept one; `Reader` holds the next id a consumer wants. `events()`,
`emit`, `update` (end of frame: the previous frame's events are dropped, the current become
previous), `reader` (starts at the newest event), `readerFromStart`, `read(events, reader) ->
(Reader, Array[T])` and `pending`. Every event stays readable for two updates, so a system that
runs before or after the sender in a frame still sees it once; a reader that falls further behind
skips what was dropped rather than reading stale data.

## Grill Log

- **Q:** Let readers consume destructively? **A:** No; several systems read the same events.
  Per-reader cursors over ids let each read independently and exactly once.

## Referenced by

[[src/Ark/_MOC]] · [[Ark World]] · [[Ark Hierarchy Fixture]]
