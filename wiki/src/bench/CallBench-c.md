---
type: module
path: "@root/bench/CallBench.c"
fidelity: Active
tags: [module, benchmark, native, calls]
aliases: [Native Call Floor]
---

# Native Call Floor

## Purpose and interface

The loop of [[Native Call Benchmark]] written by hand in C: `mix` with the same checked
multiplication and addition (overflow aborts), `run` marked non-inlinable, and the same
warmup and timed sections measured on the monotonic clock. It prints the same line shape.
It is the floor that a compiled Pudu call is measured against, not a competitor.

## Resolved Grill Log

- **Q:** Drop the checked arithmetic to match C idioms? **A:** No; the overflow checks are part of
  what a Pudu call must pay, so removing them would flatter the floor.

## Referenced by

[[src/_MOC]] · [[Native Call Benchmark]]
