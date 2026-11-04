---
type: module
path: "@root/bench/WorldBench.pudu"
fidelity: Active
aliases: [Ark World Benchmark]
tags: [module, ark, performance]
---
# Ark World Benchmark

Moves 100,000 entities with a position and a velocity: as an Array of records rebuilt per frame,
and as an [[Ark World]] whose movement system is three `Lanes.axpy` calls. Reports nanoseconds
per frame for each and panics unless the World result is the expected position.

## Referenced by

[[Ark World Gate]]
