---
type: module
path: "@root/bench/MotionBench.pudu"
fidelity: Active
aliases: [Ark Motion Benchmark]
tags: [module, ark, physics, benchmark]
---
# Ark Motion Benchmark

Warm up 100 moves, then time 1,000 moves through a two-wall analytic callback.
Consume position, query/contact counts and completion status; fail on typed errors or exhaustion.
Print elapsed milliseconds and checksum. This measures the local interpreter, including
callback work, not native scene throughput. The fixture owns correctness expectations.

## Resolved Grill Log

- **Q:** Time discarded calls? **A:** No; consume results into an observable checksum.
- **Q:** Infer scene acceleration from a two-plane benchmark? **A:** No; query backend is explicit.

## Referenced by

[[Ark Swept Motion]] · [[Ark Motion Delivery]]
