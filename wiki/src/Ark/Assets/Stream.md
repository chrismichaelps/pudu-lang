---
type: module
path: "@root/lib/Ark/Assets/Stream.pudu"
fidelity: Active
aliases: [Ark Asset Stream]
tags: [module, ark, assets, concurrency]
---
# Ark Asset Stream

## Purpose and interface

Asynchronous asset loading that never stalls a frame. `stream()` is empty; `request(stream,
source, priority)` queues a [[Ark Asset Server]] `Source` (a higher priority launches first, ties
by request order; a request for an ID already queued or running is ignored); `cancel(stream, id)`
drops a request that has not started.

`pump(stream, server, budget) -> Result[(Stream, Server, Progress), StreamError]` runs once per
frame and never waits. It reads the result cell of every running load; a finished one is joined,
forgotten and its cell disposed. Finished loads commit in launch order, at most
`budget.commits` per pump; the rest wait for later pumps. Then it launches waiting requests,
highest priority first, whose dependencies are all loaded and that are not loaded themselves,
until `budget.workers` loads are running: each runs `Server.prepare` on a thread over the
server value as it stands, which is immutable and safe to share. `Progress` names the IDs
`committed` and `failed` (with their errors) during this pump, the IDs `blocked` on a dependency
that is neither loaded, running nor waiting, and how many requests are `waiting` and `running`.
A request for an asset already loaded is dropped when it reaches the front.

`StreamError`: `BadBudget(workers, commits)` for a budget below one in either, and
`WorkerFailed(message)` when a thread cannot start or be joined. Read and import failures are
per asset and arrive in `Progress.failed`.

## Grill Log

- **Q:** Use `Std.Concurrent.Future` for each load? **A:** No; a future's cells belong to the
  caller and are never released, so a game streaming thousands of assets would grow without
  bound. A load owns one thread and one cell, released when it finishes.
- **Q:** Commit everything that finished? **A:** No; publishing has a cost the frame must
  bound. `budget.commits` caps it, and finished loads wait in launch order.
- **Q:** Launch a request whose dependency is still loading? **A:** No; importers read their
  dependencies' payloads, so a load starts only once those are published.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Asset Server]] · [[Ark Stream Fixture]]
