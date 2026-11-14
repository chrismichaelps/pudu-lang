---
type: module
path: "@root/bench/CharacterBench.pudu"
fidelity: Active
aliases: [Ark Character Benchmark]
tags: [module, ark, physics, benchmark]
---
# Ark Character Benchmark

Measure 1,000 capsule moves into a three-boundary corner, with a separate 100-move warmup.
[[Ark Character Movement]] receives a sphere-sized capsule and a displacement requiring multiple
sweeps. Consume every final position into a checksum; refuse failures and budget exhaustion.
Std.Time.elapsed measures the batch in whole milliseconds. Run with the optimized compiler and
the checkout library. These are interpreter measurements and include per-call boundary preparation;
they establish neither native engine throughput nor an optimized spatial-query index.

## Resolved Grill Log

- **Q:** Time a discarded result or one collision-free move? **A:** No; consume a multi-contact batch.
- **Q:** Enforce host timing in CI? **A:** No; only the deterministic behavior fixture is a gate.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Character Delivery]]
