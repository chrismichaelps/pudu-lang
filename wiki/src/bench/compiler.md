---
type: module
path: "@root/bench/compiler.mjs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
tags: [module, performance]
aliases: [Compiler Benchmark]
---

# Compiler Benchmark

## Purpose and interface

Measure observable whole-compiler latency, separately from bootstrap Haskell
builds and interpreted program execution. Run `node bench/compiler.mjs <pudu>`
with optional `--sizes 1000,2000,4000`, `--samples 3`, `--lib <root>`, `--json`
and `--rts N2,A8m`. Defaults select the repository library and optimized executable
provided by the caller. The binary is never built implicitly.

## Algorithm

Create an invocation-owned temporary workspace. Generate valid independent
functions, statement bodies, complete generic trait evidence, sparse module
graphs, a small real library composition and an all-Std root with unique aliases.
Include an intentional type mismatch, whose expected E3001 is verified. Empty
valid source measures actual process/check startup. Inputs vary by explicit size;
all ordinary declaration cases run every compiler phase reached by their syntax.

For every case collect cache-disabled samples, the first compile into a fresh
cache and subsequent warm samples. Invoke `check` with RTS statistics; record
wall milliseconds, RTS total CPU/elapsed, mutator/GC CPU, allocation and maximum
residency. Preserve all samples and report median/minimum separately. Include
binary identity/hash, library path, compiler version, host and Node version.
No startup subtraction, implicit user cache, source mutation or concurrency.

Reject launch failure, timeout, unexpected exit status, missing RTS statistics,
any unexpected diagnostic and unexpected compiler output. Known invalid source
is timed only when its exact expected diagnostic codes are present. Warm timing
for invalid source remains recompilation because diagnostics cannot be cached.
Remove scratch inputs and products on success and failure.

## Edge cases and negative logic

Validate positive integer sizes/sample counts and the supplied binary/library
before creating inputs. Standard-library modules are discovered only inside the
explicit library, in stable order. The all-Std root supplies unique aliases so
repeated segment names cannot create artificial declaration errors. Cache state
belongs to each case and mode. No absolute performance pass/fail threshold is
invented; workload growth and measured before/after evidence justify fixes.

Do not equate a Haskell compiler bootstrap with a Pudu check, include failed
compiles as successful samples, compare mismatched cache policies, or call
interpreter execution native compilation. No cache key or compiler semantics
change belongs to the harness.

## Grill Log

- **Q:** Subtract the empty process baseline? **A:** Report it separately.
  _Rationale:_ users pay actual latency and subtraction hides startup regressions.
  _Rejected:_ reporting a negative or near-zero adjusted duration as latency.
- **Q:** Trust status alone? **A:** Verify diagnostic codes and check summary,
  plus RTS statistics. _Rationale:_ an invalid workload exits sooner and can
  produce a plausible time. _Rejected:_ treating every nonzero answer as a sample.
- **Q:** Reuse the developer cache? **A:** No; make fresh isolated caches.
  _Rationale:_ cold/warm policy must be reproducible and cannot prune user data.
  _Rejected:_ ambient default caches and undocumented repeated-run state.

## Referenced by

[[src/_MOC]] · [[Performance Constitution]] ·
[[handoffs/2026-10-04-compiler-performance]]

Branch-heavy statement bodies also retain literals for later surrounding
constraints. They distinguish a linear frontend from repeated whole-queue
validation in [[Type Env]]. Source sizes use the same explicit --sizes list.

Negative statement bodies isolate pending literal sign updates, which must stop
at the unique creation identity rather than rebuilding unrelated older facts.
