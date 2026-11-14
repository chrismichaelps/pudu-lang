---
type: module
path: "@root/bench/PhysicsBench.pudu"
fidelity: Active
aliases: [Ark Physics Benchmark]
tags: [module, ark, benchmark, physics]
---

# Ark Physics Benchmark

## Purpose and interface

Simulate 1,000 radius-0.4 spheres in a five-plane pit for 120 fixed 1/60-second steps with four
solver iterations. Carry every resulting world into the next step. Exclude the first 60 steps
from measurement, then print body count, mean contact count and mean nanoseconds per step.
Setup and mesh rendering are excluded. Invoke with the optimized runtime and checkout library.

## Resolved Grill Log

- **Q:** Assert one machine's timing in CI? **A:** No; correctness gates remain independent.
- **Q:** Report the first uncongested step? **A:** No; warm up before timing the accumulating
  pile, reporting contact count beside duration so workload changes remain visible.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Physics Continuation]] · [[Ark Physics Step]]
