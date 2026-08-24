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

[[architecture/_MOC]] · [[architecture/OVERVIEW]] · [[architecture/SEMANTICS]] · [[ADR-0005-performance-and-low-level-optimization]] · [[Frontend]] · [[Semantics]] · [[Backend]]
