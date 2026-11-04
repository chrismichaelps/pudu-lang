---
type: architecture
status: ACTIVE
tags: [architecture, performance]
aliases: [Performance Constitution]
---

# Performance Constitution

## The standard library is a thin layer

`Std.List` delegates to the array's own operations rather than rebuilding arrays by hand. The array
is a finger tree, and the difference is not a constant factor:

| Operation | Delegated | Rebuilt by hand |
|---|---|---|
| `length`, `isEmpty` | O(1) | O(1) |
| `first`, `last` | O(1) | O(1) |
| `take`, `drop`, `slice` | O(log n) via split | O(n log n) via repeated push |
| `concat` | O(log(min(n, m))) via join | O(m log n) |
| `reversed` | O(n) structural | O(n log n) |
| `contains`, `indexOf`, `count` | O(n) | O(n) |
| `sum`, `product`, `minimum`, `maximum` | O(n) | O(n) |
| `sorted` | O(n log n) merge sort | O(n²) insertion sort |

Three rules follow, and they apply to every collection module:

- **Never rebuild what the structure can split or join.** A `while` loop with `push` is the wrong
  answer to `take`, `drop`, `slice`, and `concat`; each has a logarithmic operation underneath it.
- **Accept the lower bound where one exists.** `sum` must read every element and comparison sorting
  cannot beat `n log n`. A library that pretends otherwise is either wrong or is quietly a different
  data structure — a running aggregate, a prefix-sum array, a segment tree — and should say so by
  being one.
- **When the library cannot be fast, the runtime is what to fix.** If a hot operation has no
  structural form, that is a missing runtime primitive, not a reason for a cleverer loop.

Doc comments state what a function does, not its complexity. A complexity that appears in a doc
comment is a promise made in the place least likely to be updated when the implementation changes;
this table is where the promise lives.

Pudu performance has two distinct products: fast compiler/tool response and fast predictable generated programs. Neither may trade away [[architecture/SEMANTICS]].

## Compiler Throughput Laws

- Every phase is asymptotically documented and benchmarked on representative small, medium, and stress corpora.
- Source traversal is linear; recovery and diagnostics are bounded against malicious input.
- Phase data is strict by default. Hot scalar identities use nominal newtypes and may adopt unboxed/compact representations after measurement.
- Names are interned once after parsing; semantic phases compare compact symbol/type IDs, not repeated text.
- Diagnostics retain spans and lazy-render messages only where profiling proves rendering cost material; semantic identity remains structured.
- Compiler phases avoid global mutable state. Controlled local mutation in `ST` is allowed behind pure interfaces when allocation profiles justify it.
- Maps use representation matched to key shape: ordered maps for deterministic sparse domains, integer maps/arrays for dense IDs, sets/bitsets for dataflow.
- Repeated list append and text concatenation in hot paths are prohibited; use reversed accumulators, builders, or compact sequences.
- Module interfaces support content fingerprints and dependency summaries so incremental compilation can skip unchanged downstream phases.
- Parallelism occurs across independent modules/passes only after deterministic output ordering is preserved.

## Frontend Performance

- Lexer consumes at least one scalar per step and performs no backtracking over accepted tokens.
- Longest symbol matching has bounded vocabulary cost; it may become a trie only after measurement.
- Parser uses token-index cursor operations, bounded recovery, precedence climbing, and no whole-prefix copies.
- Source position rendering is off the hot compile path; line indexes are built lazily or once when diagnostics require them.
- Syntax representation begins readable and phase-owned; compact arena/index forms are admitted only with benchmark evidence and no tooling fidelity loss.

## Semantic Performance

- Resolution assigns stable dense symbol IDs.
- Type unification uses path-compressed union/find or equivalent local mutable structures when inference slice benchmarks establish need.
- Trait lookup is indexed by nominal head type and trait; no unbounded global search.
- Ownership and exhaustiveness operate on explicit control-flow graphs with worklists; joins converge monotonically and have diagnostic safety bounds.
- Core lowering removes recovery/poison nodes entirely and makes move/drop/failure/cancellation edges explicit.

## Generated-Code Pipeline

The target-neutral [[Core IR]] lowers into control-flow IR suitable for these proof-preserving passes:

1. constant folding under exact checked/wrapping/saturating numeric semantics;
2. unreachable-block and dead-value elimination while preserving destruction/IO;
3. copy propagation and local common-subexpression elimination under alias/effect constraints;
4. CFG simplification and jump threading;
5. bounded inlining using size/hotness budgets;
6. escape analysis and stack promotion where lifetime proof permits;
7. borrow-derived alias analysis;
8. bounds-check elimination only when range proof dominates the access;
9. devirtualization/monomorphization for statically known trait calls;
10. target C compiler optimization after Pudu semantics are encoded without undefined behavior.

## Optimization Barriers

- Checked overflow, left-to-right evaluation, short-circuiting, source-visible IO order, deterministic drop order, panic provenance, failure propagation, and cancellation points are observable.
- Unsafe contracts may enable lower-level assumptions only within their proven scope.
- Floating reassociation, contraction, and fast math are disabled unless a future explicit mode changes the semantic contract.
- Eliminating allocation, copy, drop, or bounds check requires a proof in the IR analysis, not pattern intuition.
- Generated C never relies on signed overflow, invalid aliasing, use-after-lifetime, uninitialized reads, or other C undefined behavior.

## Low-Level Representation Direction

- Native values use explicit layouts with target-width metadata and ABI tests.
- Sum types use discriminant plus payload layout chosen by size/alignment analysis; niche optimization is allowed only when every representation value is specified.
- Generic functions monomorphize initially; code-size budgets may choose shared implementations only when calling convention and representation remain explicit.
- Ownership enables stack allocation and deterministic destruction; escape analysis may promote non-escaping aggregates.
- Runtime helpers are small, versioned, and benchmarked; no hidden garbage collector is introduced.

## Indexing text costs what reaching the index costs

`charAt` walks the text to find the character asked for. `Str` holds UTF-8, where a character is one
to four bytes, so the byte a character index names cannot be computed — it has to be counted to. The
builtin drops that many characters and takes the first of what is left.

Every parser in the library is written as an index walking forward over a source: `Std.Json`,
`Std.Csv`, `Std.Toml`, `Std.Yaml`, `Std.Xml`, `Std.Text.Parse`, `Std.Url`. Each of those reads
position after position, and reaching each one costs what it takes to walk there — so the work to
read a document grows with the square of its length rather than with its length.

Measured on an Apple M-series host with an `-O2` runtime, decoding JSON:

| input | time |
| --- | --- |
| 118 KB | 0.85 s |
| 590 KB | 8.95 s |
| 2.46 MB | 113 s |

Five times the input is ten times the work, and four times again is thirteen times more. The
compiler's own documentation index is 24.5 MB; decoding it that way takes hours, which is how this
was found — a build step written in Pudu was abandoned and left in JavaScript.

This is a property of the representation rather than of the parsers, and the parsers cannot avoid it
while a position is a character index into text that has to be counted. Fixing it means one of: a
`Str` that carries what it costs to reach a position, a reader that holds a position rather than
handing one back to be found again, or parsers written over `Bytes`, where a position is the byte it
names. Until one of those, no parser in the library should be pointed at a document of any size, and
`Std.Bytes.Cursor` is what a program reading a large one should reach for.

## Machine-word loop regions and the #483 gate

On 2026-10-16 the backend-performance workstream (issue #483, `GHC 9.10.3/aarch64`,
`PUDU_CACHE=off`, five samples of the seven-workload `bench/eval.mjs` harness on the
optimized compiler sha256 `5619d630…`) profiled every workload by ticky attribution and
resolved one measured seam: the scalar Loop workload spends all its cost in the boxed
scalar kernel path (2.16 GB ticky, ~27 closures and 778 B allocated per iteration), so
[[Eval Loop Unboxed]] executes a fully proven pure integer while-region over unboxed
64-bit slots with identical admission, commit and diagnostics.

| workload | tree before → after (ms) | compiled before → after (ms) | allocated before → after |
| --- | --- | --- | --- |
| Arrays | 773 → 745 | 574 → 562 | 3316 MB → 3316 MB |
| Calls | 425 → 424 | 259 → 256 | 3262 MB → 3262 MB |
| Iterate | 418 → 405 | 307 → 308 | 1846 MB → 1846 MB |
| Loop | 560 → 245 | 555 → 246 | 2334 MB → 2 MB |
| Maps | 766 → 781 | 556 → 568 | 3742 MB → 3742 MB |
| MultiMap | 702 → 688 | 694 → 687 | 2580 MB → 2580 MB |
| Records | 353 → 340 | 351 → 343 | 1268 MB → 1268 MB |

Loop improves 2.29×/2.26× with a 1000× allocation cut and linear scaling to three
million iterations; every other workload stays within noise and every output, the six
focused fixture checks and all 612 optimized suite checks are unchanged.

The gate is nevertheless measurably unmet and no commit or promotion is authorized:
an equivalent `clang -O2` Loop program runs in about 0–2 ms from a 33 KB binary while
Pudu still runs 246 ms from a 98,037,480-byte compiler, the residual ≈78 ns per
iteration is interpreter closure dispatch that this representation cut cannot remove,
and the remaining workloads still run entirely boxed. Variant measurements (3M
iterations: condition+increment 112 ms, Loop 245 ms, then 366/518/627 ms as one, two
and three further `total = total + (i % k) * m` statements are added) show the
marginal cost of each statement is a flat 36–51 ns because `planInt` composes one
heap closure per expression node and calls each one indirectly every iteration; a
flat opcode-array execution of the same proven region is the identified next bounded
lever (~2–2.5× on scalar loops, larger on statement-heavy bodies) and was measured,
recorded, and deliberately not taken — the owner stopped the experiment here. The [[Package Binary]] strip
policy (verified on the real artifact) shrinks the distributed compiler to 65,766,184
bytes and attached bundles by 32.9%, which affects download bytes but not native
program speed. Reaching issue #483's millisecond gate requires the planned native
emission path, not further interpreter tuning; the branch remains uncommitted and the
full record lives in [[Backend Performance Delivery]].

## Benchmark and Regression Gates

- Criterion-style microbenchmarks: source indexing, lexing, parsing, name lookup, unification, ownership dataflow, lowering, each optimization pass, C emission.
- End-to-end corpus: tiny CLI, generic collections, error-heavy invalid source, ownership stress, async fan-out, macro expansion stress, and multi-module incremental rebuild.
- Generated-code benchmarks compare interpreter correctness first, then native latency/throughput/code size against prior Pudu releases.
- Record wall time, CPU time, maximum residency, allocations, artifact size, and cache hit/rebuild counts.
- A performance change requires before/after evidence on a pinned machine/configuration; material regressions require explicit acceptance in the PR/ADR.
- Release gates reject statistically credible regressions above the agreed per-benchmark budget; initial budgets are established only after the first stable baseline to avoid fabricated targets.

## Grill Log

- **Q:** Should we use mutable low-level structures immediately? **A:** Only inside measured hot modules behind pure contracts. _Rationale:_ strict pure structures are easier to validate; premature mutation spreads complexity. _Rejected:_ “pure at any cost”; global mutable compiler state.
- **Q:** Should optimization begin in the C compiler? **A:** Use it, but first encode Pudu semantics explicitly and own language-level optimization in Core/CFG IR. _Rationale:_ C optimizers cannot infer Pudu failure/drop/ownership rules reliably. _Rejected:_ treating generated C flags as the optimizer architecture.
- **Q:** Can ownership information improve performance? **A:** Yes; preserve alias/lifetime facts into IR for stack promotion, devirtualization, and check elimination. _Rationale:_ safety proofs are optimization assets. _Rejected:_ erasing ownership facts before lowering.
- **Q:** Set aggressive throughput numbers now? **A:** No; establish reproducible baselines first, then ratchet budgets. _Rationale:_ hardware-free targets are theater. _Rejected:_ ungrounded MB/s promises.
- **Q:** Optimize compile speed or runtime speed first? **A:** Preserve both as separate dashboards; prioritize compiler responsiveness during semantic churn and runtime hot paths once conformance stabilizes. _Rationale:_ one metric must not hide regression in the other. _Rejected:_ single composite score.

## Referenced by

[[architecture/_MOC]] · [[architecture/OVERVIEW]] · [[architecture/SEMANTICS]] · [[ADR-0005-performance-and-low-level-optimization]] · [[Frontend]] · [[Semantics]] · [[Backend]] · [[Backend Performance Delivery]]
