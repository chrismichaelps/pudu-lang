---
type: handoff
status: REVIEW_PENDING
issue: 483
aliases: [Backend Performance Delivery]
tags: [handoff, performance, backend, release]
---
# Backend Performance Delivery

Issue #483 starts from fetched dev c13dd93e in the managed backend-performance
worktree, on feature/483-backend-performance. The user authorizes a direct dev
commit only after measured millisecond performance and competitive equivalent
C/C++ sizes. No commit or promotion is authorized when that condition is unmet.

Transitions: Delivery Owner → Language Architect → Performance Engineer.
Architect owns this handoff, MOCs, changelog and integration evidence. Runtime
and binary investigators own local experiment artifacts only until measurement
resolves their implementation boundaries. Benchmark author owns bench/eval.sh,
a dedicated runtime measurement harness, its tests and complete mirrors.
Packaging author owns scripts/package-binary.py, focused strip-policy tests and
their complete mirrors. Runtime author will own one measured runtime seam and
its tests/mirrors after attribution. Agents are not alone; preserve other work.

Resolved Grill Log: use the actual import/SCC dependency graph joined to fresh
exclusive ticky/profile measurements from identical source. Import depth alone
is not causal evidence. Keep compiler latency, interpreted runtime, bundled
program bytes and compressed compiler download bytes separate. Preserve each
existing workload and validate its exact output. Compare ordinary optimized
binaries; instrumented timings never satisfy acceptance. A comparable C/C++
program establishes a target, not compiler/language feature parity.

The current build packages a Haskell compiler/evaluator with source products;
C11 native emission remains planned. Do not claim native-code size or speed.
GHC 9.10.3 is available locally; the locked 9.14.1 matrix is unverified.

Measured record (2026-10-16, GHC 9.10.3/aarch64, fresh baseline `/tmp/baseline-483.json`,
final `/tmp/final-483.json`, both 5 samples over all seven workloads and both modes):
[[Eval Loop Unboxed]] executes the proven integer while-region over unboxed 64-bit
slots and takes Loop from 560/555 ms to 245/246 ms tree/compiled with allocation
2,334 MB to 2 MB; linear to 3M iterations; every other workload within noise and
all outputs unchanged. Full optimized suite: 612 checks, exit 0. All debug traces
removed; the measured binary is sha256 `5619d6301fc7aab741545a61e77c8da19ac2b8f2eabb4a7b825245aeea3253ec`
at 98,037,480 bytes. [[Package Binary]] strip policy verified on the real artifact:
Mach-O `NOUNDEFS` arm64, ad-hoc signature valid, identical 13-dylib list, extracted
runs of Loop plus five DB fixtures (real `sqlite::memory:`) byte-identical to the
unstripped compiler, and a 32.9% smaller attached bundle (65.8 MB vs 98.0 MB).

Residual gap: about 78 ns of interpreter closure dispatch per iteration remains and
the 98 MB compiler binary does not compete with native sizes, so issue #483's commit
gate is measurably unmet. This work is committed on feature/483-backend-performance
as the issue's measured record and opened as a PR to dev for review; nothing is
promoted and the gate is not claimed as met.

Exact next action: Language Architect review of the open PR (withheld-promotion
record consolidated in [[Performance Constitution]]: per-workload before/after table,
Loop's clang -O2 reference ~0-2 ms and 33 KB, residual-dispatch analysis, and the
identified flat-instruction next lever) plus Forensic Guardian wiki-parity review;
then decide whether to close issue #483 as a measured negative against its gate or
schedule the native C11 emission path this record now seeds.

## Referenced by

[[handoffs/_MOC]] · [[Performance Constitution]] · [[Dependency Layer Report]]
