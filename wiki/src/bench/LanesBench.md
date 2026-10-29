---
type: module
path: "@root/bench/LanesBench.pudu"
fidelity: Active
aliases: [Lanes Benchmark]
tags: [module, performance, lanes]
---
# Lanes Benchmark

Integrates 100,000 positions for ten frames twice: an Array loop with indexed updates, and one
`Lanes.axpy` per frame. It panics unless both produce identical values, then prints each elapsed
time in milliseconds. [[Lanes Gate]] reports the ratio with `--bench`.

## Referenced by

[[Lanes Gate]] · [[Lane Delivery]]
