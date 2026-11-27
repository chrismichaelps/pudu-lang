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
milliseconds, and optionally a built native executable's runtime on the same
fixtures. `node bench/eval.mjs <pudu>` defaults to Arrays, Calls, Iterate, Loop,
Maps, MultiMap and Records, both tree/compiled, and five raw samples. Options
are `--samples <positive integer>`, `--lib <library>`, `--json`,
`--benchmarks <comma-separated names>`, `--modes <tree,compiled,native>` and
`--timeout-ms <positive integer>`. A caller supplies an ordinary optimized
binary; the harness never builds or profiles one implicitly. Native mode asks
that binary for a fixture executable, so its build cost is reported once per
fixture rather than folded into a sample.

## Algorithm and identities

Resolve binary and library to absolute real paths; the library must contain Std.
Verify the exact known fixture membership and keep their sources unchanged.
For every sample bracket synchronous subprocess launch/completion with
`process.hrtime.bigint()`, then divide nanoseconds by one million. Force
PUDU_CACHE=off, explicit PUDU_EVAL and absolute PUDU_LIB. Invoke RTS -s and retain
allocation, maximum residency and total RTS CPU/elapsed time alongside wall time.
In native mode, build each fixture once with `pudu build <fixture> --native -o
<scratch>` into a temporary directory removed after the report; record build
time, binary SHA256 and bytes, then time only the executable. Native samples
carry wall time but no RTS statistics. No startup subtraction, concurrency or
user-cache reuse is permitted.

Require exit zero and stdout exactly equal to the established newline-terminated
result: Arrays 249999500000; Calls 196418; Iterate 2399960; Loop 26999982;
Maps 68749875000; MultiMap 640000; Records 0. Unexpected diagnostics, missing RTS
statistics, signal, spawn failure, timeout and any output difference fail. A
failed native build, a build that writes no executable, a native exit, signal or
output difference also fail without a report. Store every sample with minimum
and median; tree and compiled rows are labelled startup plus checking plus
runtime, native rows runtime only.
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
- **Q:** Compare native and evaluator rows as one number? **A:** No; each mode
  names its scope. _Rationale:_ evaluator rows include startup and checking,
  native rows time only the emitted executable. _Rejected:_ subtracting an
  assumed startup cost.
- **Q:** Rebuild the native executable for every sample? **A:** No; build once
  per fixture and report build time beside the samples. _Rationale:_ compilation
  is not runtime. _Rejected:_ charging every run with its build.

## Referenced by

[[Runtime Benchmark Entry]] · [[Runtime Benchmark Tests]] · [[src/_MOC]] ·
[[Backend Performance Delivery]] · [[Benchmark Guide]]
