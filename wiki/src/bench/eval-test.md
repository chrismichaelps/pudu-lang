---
type: module
path: "@root/bench/eval.test.mjs"
fidelity: Active
tags: [module, test, tooling, performance]
aliases: [Runtime Benchmark Tests]
---

# Runtime Benchmark Tests

## Purpose and interface

`node --test bench/eval.test.mjs` establishes [[Runtime Benchmark]] without a
compiler build. Invocation-owned temporary executables emit independently chosen
exact outputs and RTS-statistics fixtures, then are removed after each test.

## Test contract

The successful CLI case covers both evaluators and all seven fixed workload
outputs; it asserts five default samples, positive unrounded monotonic wall
milliseconds, raw RTS data, absolute library identity, binary/fixture SHA256,
host metadata and independent median arithmetic. A fixture executable asserts
that PUDU_CACHE is off even when the caller exports a cache directory, and that
PUDU_LIB is absolute. Wrapper invocation with a spaced binary path must preserve
arguments and return the same report.

Refusal tests cover nonzero status, successful wrong output, missing output,
unexpected diagnostics, missing RTS data, invalid modes/benchmark names, zero
samples and duplicate flags. No failure may emit a completed JSON result.
Expected stdout includes its final newline, preventing trimming from concealing
an output regression. Tests use independent numeric RTS assertions rather than
snapshots of the implementation.

## Resolved Grill Log

- **Q:** Wait for real large evaluator workloads in focused tests? **A:** No;
  deterministic fake executables establish measurement and refusal contracts.
  _Rationale:_ actual optimized binaries separately establish runtime evidence.
- **Q:** Test only returned medians? **A:** Test sample retention, environment,
  provenance and exact failed execution. _Rationale:_ correctness of the measured
  workload matters before any speed claim.

## Referenced by

[[Runtime Benchmark]] · [[src/_MOC]] · [[Backend Performance Delivery]]
