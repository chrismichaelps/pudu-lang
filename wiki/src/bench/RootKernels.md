---
type: module
path: "@root/bench/RootKernels.pudu"
fidelity: Active
aliases: [Root Kernel Benchmark]
tags: [module, math, performance]
---
# Root Kernel Benchmark

## Purpose and algorithm

Compare reciprocal of [[Std Math Float]] sqrt with private binary64 reciprocal estimates using
one/two Newton refinements. On inputs in [1,3], use the exact `Float.toBits`/`Float.fromBits` kernels and
the published initial-approximation constant 0x5fe6ec85e7de30da. Implement the numeric technique
independently; no external engine code is imported. The production square root remains allocation-free.

Main prints sampled accuracy rows on a 1/256 grid, warms all methods, then records five repeated
batches with alternating order. Every batch walks the same six inputs and consumes its checksum;
clock readings are milliseconds. [[Square Root Range Gate]] parses optional benchmark output.
These timings include Pudu evaluator, loop and callback costs; they do not measure a native
instruction or establish a uniform approximation guarantee. Private estimates accept only the
benchmark's positive normalized domain and are not a general public engine API.

## Resolved Grill Log

- **Q:** Reuse a binary32 constant for binary64 values? **A:** No; keep precision and representation explicit.
- **Q:** Use raw pointer type punning? **A:** No; use the exact bit-cast kernels.
- **Q:** Add a fast engine path just because the formula is famous? **A:** No; decide from measured
  runtime cost and sampled error, keeping precise/general and approximate/specialized work separate.

## Referenced by

[[Std Math Float]] · [[Square Root Range Gate]] · [[Square Root Delivery]] · [[src/_MOC]]
