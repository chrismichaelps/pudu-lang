---
type: module
path: "@root/bench/README.md"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
tags: [module, documentation, performance]
aliases: [Benchmark Guide]
---

# Benchmark Guide

## Purpose and interface

Explain the measurement order: whole-compiler cold/warm corpus, growth-rate
harnesses, request latency/throughput, cost-centre profiling, then one module's
optimized intermediate forms. Command examples must select an optimized binary
with the same Cabal flags as its build.

## Algorithm and dependencies

[[Dependency Layer Report]] joins source-import SCCs and dependency layers to
exclusive GHC CPU/allocation or ticky allocation/entry costs. It emits an offline
treemap and companion JSON with provenance, source navigation, coupling and cycle
summaries. Structural-only mode measures no resource cost; unknown attribution,
instrumentation overhead and imports across CPP branches remain explicit.

The whole-compiler guide points to [[Compiler Benchmark]], whose JSON includes
cache policy, raw milliseconds, CPU, allocations, residency and binary/host
identity. Existing graph/scaling tools establish workload growth; request.mjs
separates network baseline, encoded data and rendered page costs. profile.sh
names hot compiler functions; ir.sh inspects their Core, STG, Cmm or assembly.
Profiling and IR builds are separate directories because cached ordinary products
cannot supply their diagnostics. Neither tool describes generated Pudu machine
code; interpreted program work remains separately measurable.

## Negative logic and edge cases

Do not quote an unoptimized binary as shipped performance, count rejected input
as a fast compile, or hide cache/startup assumptions. Preserve the existing tools
and their failure contracts. The first profiling/IR build takes minutes; that
bootstrap is not the check latency being measured.

## Grill Log

- **Q:** Treat an import graph as proof of a performance defect? **A:** No;
  measured exclusive costs select investigation paths; coupling and SCCs supply
  context. Instrumented timings are not ordinary-binary acceptance measurements.

- **Q:** Inspect assembly before workload measurement? **A:** No. _Rationale:_
  the measured growth or allocation names the layer worth investigating.
  _Rejected:_ whole-compiler dumps without a hotspot.
- **Q:** Use Cabal's default list-bin command? **A:** Pass optimization=2.
  _Rationale:_ the development project disables optimization. _Rejected:_ a
  command silently choosing a different configuration than the shipped build.

## Referenced by

[[src/_MOC]] · [[Compiler Benchmark]] · [[Performance Constitution]]
