---
type: module
path: "@root/bench/eval.mjs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
tags: [module, performance]
aliases: [Runtime Benchmark]
---

# Runtime Benchmark

## Purpose and interface

Measure `pudu run` process startup, checking and execution together in actual
milliseconds. `node bench/eval.mjs <pudu>` defaults to Arrays, Calls, Iterate,
Loop, Maps, MultiMap and Records, both tree/compiled, and five raw samples.
Options are `--samples <positive integer>`, `--lib <library>`, `--json`,
`--benchmarks <comma-separated names>`, `--modes <tree,compiled>` and
`--timeout-ms <positive integer>`. A caller supplies an ordinary optimized
binary; the harness never builds or profiles one implicitly.

## Algorithm and identities

Resolve binary and library to absolute real paths; the library must contain Std.
Verify the exact known fixture membership and keep their sources unchanged.
For every sample bracket synchronous subprocess launch/completion with
`process.hrtime.bigint()`, then divide nanoseconds by one million. Force
PUDU_CACHE=off, explicit PUDU_EVAL and absolute PUDU_LIB. Invoke RTS -s and retain
allocation, maximum residency and total RTS CPU/elapsed time alongside wall time.
No startup subtraction, concurrency or user-cache reuse is permitted.

Require exit zero and stdout exactly equal to the established newline-terminated
result: Arrays 249999500000; Calls 196418; Iterate 2399960; Loop 26999982;
Maps 68749875000; MultiMap 640000; Records 0. Unexpected diagnostics, missing RTS
statistics, signal, spawn failure, timeout and any output difference fail.
Store every sample with minimum and median, labelled checking plus runtime.
JSON records timestamp, binary SHA256/bytes/path/version, per-fixture SHA256/path,
absolute library, Node, host OS/architecture/CPU/count and available GHC/Cabal
versions. These host tool versions alone do not prove the binary's build flags.

## Negative logic and edge cases

Reject missing/incomplete/unknown/duplicate options, non-positive sample counts
or timeouts, invalid/doubled fixture/mode names, non-file/non-executable binaries
and invalid libraries before measurements. With --json, emit one complete JSON
report only after all requested samples validate. A partial run cannot masquerade
as a completed report. Keep chronological sample order and use an even-count
median average. Human output names milliseconds, min and median explicitly.

## Resolved Grill Log

- **Q:** Trust a fast process exit? **A:** Verify output, status and RTS data.
  _Rationale:_ a rejected or wrong program can be faster. _Rejected:_ discard
  stdout and report any duration.
- **Q:** Warm the ambient compiler cache? **A:** Force cache off for every run.
  _Rationale:_ source-check work is part of this contract; reproducible changes
  need identical policy. _Rejected:_ uncontrolled cold/warm mixing.
- **Q:** Report only the minimum? **A:** Keep raw points plus min and median.
  _Rationale:_ noise and spread remain reviewable. _Rejected:_ opaque best case.
- **Q:** Call this native performance? **A:** Name process/checking/runtime scope.
  _Rationale:_ these evaluators do not emit Pudu machine code.

## Referenced by

[[Runtime Benchmark Entry]] · [[Runtime Benchmark Tests]] · [[src/_MOC]] ·
[[Backend Performance Delivery]] · [[Benchmark Guide]]
