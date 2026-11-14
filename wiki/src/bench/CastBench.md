---
type: module
path: "@root/bench/CastBench.pudu"
fidelity: Active
aliases: [Ark Cast Benchmark]
tags: [module, ark, physics, benchmark]
---
# Ark Cast Benchmark

Measure 1,500 capsule-box casts across sphere-face, sphere-edge and tilted-capsule cases after a
separate warmup. [[Ark Capsule Box Cast]] supplies contact fractions; consume each result into a
checksum and refuse errors/misses. Std.Time.elapsed times the batch in whole milliseconds.
These are local interpreter measurements, including distance queries and request validation.

## Resolved Grill Log

- **Q:** Benchmark only a miss or a discarded answer? **A:** No; use three contact geometries and consume fractions.
- **Q:** Assert host timings in CI? **A:** No; deterministic fixture assertions own correctness.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Cast Delivery]]
