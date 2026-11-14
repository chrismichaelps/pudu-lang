---
type: module
path: "@root/bench/MorphBench.pudu"
fidelity: Active
aliases: [Ark Morph Benchmark]
tags: [module, ark, performance, animation]
---
# Ark Morph Benchmark

Builds a 10,000-vertex [[Ark Morph]] with 48 sparse targets of 500 vertices each and 2 dense
targets, then times 60 blends with 5 targets active (3 sparse, 2 dense). Prints nanoseconds per
blend and panics unless the blended normals stay unit length.

## Referenced by

[[Ark Animation Gate]] · [[Ark Morph]]
