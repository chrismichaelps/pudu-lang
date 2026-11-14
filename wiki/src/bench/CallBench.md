---
type: module
path: "@root/bench/CallBench.pudu"
fidelity: Active
tags: [module, benchmark, native, calls]
aliases: [Native Call Benchmark]
---

# Native Call Benchmark

## Purpose and interface

Measure 20,000,000 calls of the non-recursive scalar `mix(acc, value) = (acc * 31 + value) % 1000003`
made inside `run`, after a 1,000,000-call warmup. Print the elapsed milliseconds, the checksum
and the warmup checksum. Compare the result with [[Native Call Floor]], the same loop written by
hand in C with the same checked arithmetic. Build with the optimized runtime, at `-O2`.

## Results

Recorded timings are in [[Native Direct Calls Delivery]].

## Resolved Grill Log

- **Q:** Time the first call? **A:** No; the warmup runs the same loop first so the timed run measures
  steady calls rather than startup.

## Referenced by

[[src/_MOC]] · [[Native Direct Calls Delivery]] · [[Backend Frame Direct]]
