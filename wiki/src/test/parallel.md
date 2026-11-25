---
type: module
path: "@root/test/parallel.sh"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, parallel, runner]
aliases: [Test Parallel Runner]
---

# Test Parallel Runner

Runs the property suite on every core.

## Purpose and interface

Builds the suite once, lists every property label (`PUDU_TEST_LIST`), narrows the list by
`PUDU_TEST_MATCH`, and runs each property as its own job (`PUDU_TEST_LABEL`) on `PUDU_TEST_JOBS`
workers, defaulting to the core count.

## Contract

- Jobs start longest first, using the seconds the previous run recorded in
  `~/.cache/pudu-test/durations`. A property with no record starts first.
- Every compile goes through [[Test Compile Cache]].
- Each failing property is reported with its counterexample, followed by the totals.
- The process exits non-zero on any failure.
- Builds an optimized suite in `dist-test-opt` by default, since the suite compiles large programs in-process; `PUDU_TEST_DEBUG=1` uses the unoptimized suite in `dist-fast`.
- Drops recorded seconds for labels the suite no longer has.

## Grill Log

- **Q:** Run the properties one by one in a single process? **A:** No. _Rationale:_ that run spends
  most of an hour waiting on compiles and on the first launch of each new binary. Per-property jobs
  with longest-first ordering keep every core busy and stop one slow property from finishing last.
  _Rejected:_ a single sequential process.

Resolved Grill Log: per-property jobs on all cores, ordered by recorded duration, with every compile
served from the content-addressed cache.

Measured on an eight-core machine: one sequential process took about fifty minutes; the parallel runner with the compile cache takes about eleven minutes with the unoptimized suite and about six with the optimized one, all 903 properties passing. Groups of independent large programs are registered one property per program so they spread across workers.

## Referenced by

[[Repository Test Runner]] · [[Test Compile Cache]] · [[architecture/DELIVERY]]
