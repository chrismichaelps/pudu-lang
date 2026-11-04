---
type: module
path: "@root/bench/eval.sh"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
tags: [module, performance]
aliases: [Runtime Benchmark Entry]
---

# Runtime Benchmark Entry

## Purpose and interface

Preserve `bench/eval.sh <pudu>` as the runtime benchmark entry point. Forward
all arguments to [[Runtime Benchmark]] using Node; its defaults measure the
same seven fixtures in tree and compiled modes with five samples per case.
Optional arguments and exact refusal behavior belong to that one harness.

## Algorithm and dependencies

Resolve the wrapper's own directory and `exec node` its `eval.mjs`. Shell and
Python startup never bracket an individual measurement. The wrapper does not
build the compiler, alter fixtures, select an ambient cache or subtract startup.

## Negative logic and edge cases

Strict shell settings propagate a missing Node executable or harness failure.
Paths and arguments remain quoted, including binaries whose paths contain
spaces. The inherited PUDU_LIB is resolved and validated by the Node harness.

## Resolved Grill Log

- **Q:** Preserve the Python wall-clock shell timer? **A:** Replace it with one
  monotonic Node process. _Rationale:_ extra Python processes and rounded seconds
  distort small latency. _Rejected:_ more decimal places on the same timer.
- **Q:** Maintain a second measurement implementation? **A:** No; exec the
  dedicated harness. _Rationale:_ one validation/timing contract prevents drift.

## Referenced by

[[Runtime Benchmark]] · [[src/_MOC]] · [[Backend Performance Delivery]]
