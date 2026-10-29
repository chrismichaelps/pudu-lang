---
type: module
path: "@root/bench/LaneParallel.pudu"
fidelity: Active
aliases: [Lane Parallel Benchmark]
tags: [module, performance, concurrency]
---
# Lane Parallel Benchmark

Runs four independent lane workloads (a 400,000-element ramp through forty square-root passes,
then a sum) and four integer loops through `Concurrent.mapBounded` with one worker and with four.
Prints milliseconds for each, and panics unless both worker counts give identical results. Each
kernel writes a fresh 3.2 MB buffer, so the run is dominated by large-object allocation.

## Referenced by

[[Lane Collection Gate]] · [[Pudu Cabal]]
