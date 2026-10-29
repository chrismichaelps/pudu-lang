---
type: module
path: "@root/bench/ScheduleBench.pudu"
fidelity: Active
aliases: [Ark Schedule Benchmark]
tags: [module, ark, performance]
---
# Ark Schedule Benchmark

Builds 200,000 entities in four tagged archetypes with position, velocity, color and heat, and
an [[Ark Schedule]] of three non-conflicting systems (integrate, fade, cool) that packs into one
stage of twelve jobs. Runs 30 frames with one worker and with four, reports nanoseconds per frame
for each, and panics unless both worlds hold the same expected values.

## Referenced by

[[Ark World Gate]]
