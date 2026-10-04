---
type: handoff
tags: [handoff, performance, compiler]
---

# Compiler checking latency

Issue #435 starts from freshly fetched dev (71fb2adf) in
`feature/435-compiler-latency`, isolated from the active Derive checkout.
Architect → Tooling/Performance Engineer owns the whole-compiler benchmark and
its measured hotspot. Work is solo. Preserve canonical graph visibility,
semantics, diagnostic products and cache validity. No PR or dev promotion yet.

The dependency layers are process/RTS startup → source discovery → frontend →
shared graph interfaces → per-module expansion/resolution/checking → constants
→ persistent products → CLI reporting. Measure before changing each layer.
Haskell bootstrap build time and interpreted program time are distinct outputs;
a reduced CI build cannot claim a faster Pudu type checker.

Baseline on the Derive checkpoint binary, GHC 9.10.3, optimized, cache disabled:
25/50/100/200 sparse modules take 53/77/136/216 milliseconds and allocate
34/67/134/272 MB. A valid graph importing all 214 Std modules with unique aliases
takes 1,179 ms and allocates 1.919 GB. A valid seven-library composition takes
202 ms. Scratch failures from incorrect imports/alias collisions are excluded.
Reproduce on the dev binary before attributing a fix to this issue.

Resolved Grill Log: profile the slow layer and preserve its observable products;
failed checks are harness failures, never successful fast samples. Use fresh
cache directories and explicit cold/warm cases. Record actual wall time and RTS
CPU/allocation/residency, without subtracting startup from displayed latency.
The benchmark is a standalone measurement tool, not a wall-clock unit test.

## Exact next action

Make the measured expression-type publication map demand-driven, then compare
allocation and peak RSS on the same optimized branch-heavy check.

## Referenced by

[[handoffs/_MOC]] · [[Performance Constitution]] · [[Compiler Program]]

Architect → Semantic/Performance Engineer owns Type.Env, Type.Frontier and its
spec, test registration, benchmark and mirrors. Profiling places type checking
in the dominant layer. A valid branch-heavy body at 1,000/2,000/4,000/8,000
statements allocates 318 MB/1.15 GB/4.35 GB/16.90 GB and checks in approximately
94/292/1,033/4,208 ms. The creation-frontier selectors partition every pending
literal rather than the recent interval; exploit their existing decreasing order.
No scheduler policy change is justified: the compiler-only probe did not improve
with fewer capabilities. Preserve runtime concurrency and explicit flag handling.

The frontier checkpoint passes the optimized warning-as-error build and all 464
property families on GHC 9.10.3. The diagnostic inventory reports 154 codes,
33 shared groups and 243 sources. The harness refuses malformed arguments and
missing RTS statistics. Local toolchain evidence does not claim the locked CI
GHC 9.14.1 has run.

Three cache-disabled samples with matching dev library and ordinary optimized
binaries measure 8,000 branches at a minimum 4,105.4 ms before and 287.3 ms after;
allocation falls from 16,902,136,984 to 524,985,232 bytes. At 4,000 branches it
falls from 1,032.8 to 151.6 ms. Negative literal bodies fall from 326.4 to 83.7 ms.
All 213 Std modules remain about 1,115 ms and 1.80 GB allocation. Do not attribute
unaffected layers or warmed product reuse to the frontier fix.

The 525 MB is cumulative allocation. RTS reports about 47 MB maximum live heap
and 152 MiB heap memory in use. A separate macOS wait4 measurement gives about
170 MB process peak RSS. On an equivalent 8,000-conditional C checking workload,
Clang 21.1.8 measures 31 ms and about 30 MB RSS after the first run (first run
298 ms). The languages and compiler products differ; this comparison establishes
a target, not language-feature or native-code parity.

Forced-GC phase attribution measures roughly 122 MB lexing, 84 MB parsing,
27 MB expansion, 30 MB resolution, 172 MB type checking and 89 MB type-product
publication. Expression map construction accounts for 87.5 MB of the final
phase. Sorted bulk construction saves only 21 MB and was slower in the probe;
do not adopt it merely because fewer bytes were measured. Diagnostic-only
callers should avoid building this unused map while tooling retains its answers.
