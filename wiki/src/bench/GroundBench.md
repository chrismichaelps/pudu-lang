---
type: module
path: "@root/bench/GroundBench.pudu"
fidelity: Active
aliases: [Ark Ground Benchmark]
tags: [module, ark, physics, benchmark]
---
# Ark Ground Benchmark

Warm up 100 settlements then time 1,000 descending capsule floor probes. Consume snapped position,
mode, support distance and velocity; fail on errors or absent support. Print milliseconds and
checksum using Std.Time.elapsed. This is local interpreter evidence including the analytic callback,
not native scene throughput. No per-call collection is constructed in the settlement source.

## Resolved Grill Log

- **Q:** Discard answers while timing? **A:** No; verify and consume observable results.
- **Q:** Infer large-scene performance? **A:** No; scene acceleration and native execution stay open.

## Referenced by

[[Ark Capsule Support]] · [[Ark Ground Delivery]]
