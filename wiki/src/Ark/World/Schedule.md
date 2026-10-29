---
type: module
path: "@root/lib/Ark/World/Schedule.pudu"
fidelity: Active
aliases: [Ark Schedule]
tags: [module, ark, world]
---
# Ark Schedule

## Purpose and interface

Parallel system scheduling for [[Ark World]]. A `System` is a record: `name`, the archetype
filter `all`/`none`, the components it `reads` and `writes`, the systems it runs `after`, and
`run: fn(View) -> Option[View]`. `build(world, systems) -> Result[Schedule, ScheduleError]`
validates and packs the systems into stages; `stageNames(schedule)` reports them;
`run(world, schedule, workers) -> Result[World, RunError]` executes every stage.

Two systems conflict when one writes a component the other reads or writes. Explicit `after`
edges are ordered first by a topological pass that breaks ties by declaration position; a
conflicting pair is then ordered by that position, so declaration order is the fallback contract
exactly as it is when systems run one by one. Each system lands in the earliest stage after
every system it follows or conflicts with, and a stage lists its systems in that order.

A stage expands into one job per (system, matching archetype). Every job reads the world as the
stage found it, through a view `World.restrict` cut down to the system's declared columns: a
read or write outside its declaration answers `None` and fails the run as `SystemFailed(name,
archetype)` instead of racing. Jobs run on `Concurrent.mapBounded` with `workers` threads, or
inline for one worker or one job; results merge in job order with `World.commitComponents`
copying only declared writes. Because a stage holds no conflicting pair, the result equals
running its systems sequentially in stage order, whatever the worker count.

`ScheduleError`: `EmptyName`, `DuplicateSystem(name)`, `UnknownComponent(system, component)`
for any unregistered filter or access name, `UnknownDependency(system, missing)`, and
`Cycle(names)` listing the unordered systems by declaration. `RunError`: `SystemFailed(system,
archetype)`, `BadWorkers(count)` for fewer than one worker, and `WorkerFailed(message)` when a
thread cannot be started or joined.

## Grill Log

- **Q:** Infer access by running systems once and recording columns? **A:** No; observed access
  depends on data, so a stage proven safe on one frame races on the next. Declared access is
  checked by construction because the view simply lacks every undeclared column.
- **Q:** Let parallel results write back whole views? **A:** No; a view also carries columns the
  system only read, and committing them would undo a peer's writes. Only declared writes merge.
- **Q:** Order conflicting systems by graph discovery or name? **A:** Declaration position.
  It is the order a reader sees and the order sequential execution would use, so parallel
  stages never change a result.
- **Q:** Start threads for a stage of one job? **A:** No; a single job or a single worker runs
  inline, so a schedule never pays thread start-up where nothing overlaps.
- **Q:** Split one archetype across workers? **A:** Not in this slice. Archetype columns are whole
  lanes processed by native kernels; row-range splitting needs a lane slice and splice contract.

## Referenced by

[[src/Ark/_MOC]] · [[Ark World]] · [[Ark Schedule Fixture]] · [[Ark Schedule Benchmark]]
