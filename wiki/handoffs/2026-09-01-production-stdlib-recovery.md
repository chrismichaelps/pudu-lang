---
type: handoff
status: ARCHITECTURE
issue: 193
tags: [handoff, stdlib, runtime, production-readiness]
---

# Production Standard-Library Recovery

## Objective

Reconcile the in-progress `feature/193-std-bytes-streaming` branch with the vault, stabilize the
runtime-backed standard-library boundary, then close the remaining implementation-status gaps as
reviewable vertical slices rather than treating file presence as completion.

## Recovered State

The branch already contains committed implementations for bytes, streaming files, paths, CSV,
UUIDs, time formatting, benchmarks, threads, channels, synchronization, and TCP networking. Its
working tree additionally contains hashing primitives, callback-environment repair, an HTTP server,
and a PostgreSQL protocol/client. These changes predate their required mirrors and collectively
exceed the delivery size gate; this handoff records recovery rather than retroactively claiming the
gate was met.

`Std.HashMap` and `Std.Toml` have since shipped: the first under [[ADR-0015]], the second split
across `Std.Toml`, `Std.Toml.Read`, and `Std.Toml.Scan`. `Std.Tls` remains absent by decision
rather than by omission — see the blockers below. Package management and release-scale
large-input evidence remain later slices. Public implementation status and [[architecture/STDLIB]]
must describe shipped behavior only after its focused and full gates pass.

## Role Transitions

1. **Language Architect:** reconcile concurrency, hashing, network/resource, TLS, package, and
   compatibility contracts in the vault before extending implementation.
2. **Runtime/Stdlib Implementer:** own only the files named by the current vertical slice; preserve
   all unrelated and pre-existing changes.
3. **Independent Reviewer:** review the resulting diff without editing first and classify findings
   P0–P3.
4. **Forensic Guardian:** verify mirror fidelity, MOCs, backlinks, changelog, private-boundary
   compliance, and exact validation evidence.

## Validation Baseline

- Sandboxed full test: socket fixture reports the operating-system permission denial as a typed
  failure; this is not a language failure.
- Unsandboxed focused fixtures: Net 10/10, callback closure 8/8, HTTP server 35/35, DB 33/33.
- The full test executable runs longer than the foreground tool's sixty-second process window and
  must be run through a durable logged gate before readiness is claimed.
- The first durable full run emitted 190 successful QuickCheck groups and no falsification, then
  terminated before the remaining groups with Cabal failure status. Treat this as an unresolved
  resource/test-runner failure, not a green full gate.
- After runtime ownership hardening: library/executable build passes; focused fixtures report
  Concurrent 22/22, Net 10/10, HTTP server 35/35, DB 33/33, and UUID/entropy 24/24.
- `cabal build all --ghc-options=-Werror` passes with no warnings. CI additionally builds at `-O2`;
  that variant was not run here because the volume is full.
- `pudu fmt --check` passes over every committed Pudu file, and `test/diagnostic-codes.mjs` passes
  once `E7009` is recorded as shared — it is reported both where an effect is refused during
  constant folding and where starting a thread is.
- Every one of the fifty-six standard-library fixtures was run individually through the same entry
  path the suite uses, and each answered exactly the count `ProgramSpec` asserts, including the two
  that legitimately answer zero. New: HashMap 43/43 and Toml 44/44.
- **The unfiltered full suite completes green: 309 groups, no falsification.** The earlier reading
  that the host could not finish it was wrong twice over. The run was not killed and was not short
  of memory; it was spinning. Output was block-buffered, so the last line printed named a group
  that had already passed rather than the one still running, and every conclusion drawn from that
  line pointed at the wrong place. Run through a pseudo-terminal the line buffers, and the true
  position is `structured scopes join every task they start`; a stack sample there shows the main
  thread inside equality comparison, not inside collection.

  The cause is that releasing a child from its scope removed it by comparing values, and comparing
  two closures compared the environments they captured. A closure's captured environment reaches
  its own scope, so that comparison had no end; extending a scope to reach the root module made
  every release walk the whole program. Closure equality is now identity over name, receiver, and
  function, which is the question a release is actually asking. Mark-compact collection was never
  relevant, and requesting it is what caused the second, separate stall.

## Production Blockers Found During Recovery

- Runtime handle/socket/thread/channel/mutex/cell tables were process-global. They are now isolated
  per evaluation and covered by a direct cross-store regression; the unfiltered full gate remains.
- Host workers are joined manually or killed at program teardown rather than owned by lexical async
  scopes; blocking operations have neither cancellation points nor deadlines.
- Mutex release now proves host-thread ownership and rejects foreign or repeated release.
- Channel enqueue/dequeue/pending now use `Seq` with constant-time queue operations.
- PostgreSQL SCRAM now obtains its client nonce from bounded operating-system entropy and fails
  closed; deterministic `Std.Random` remains separate for simulation and repeatable tests.
- `Std.Time.Format` was split into a 494-line codec over a 60-line calendar. `Std.Http.Server` (666)
  is now a 350-line server over a 279-line router and a 62-line set of replies, and `Std.Db` (768)
  is a 395-line surface over a 389-line session. Both splits fell along seams that were already
  there: routing answers what a request means without a connection, and a session is what a
  connection holds between statements. Callers import the piece they use rather than reaching
  through a forwarding wall.
- `Std.Tls` is deliberately not written. A transport-security implementation in Pudu would have to
  be trusted with certificate-chain and hostname verification, and an unreviewed one is worse than
  none because callers would believe it. It waits on a vetted implementation behind a foreign
  boundary, which is the same gate the foreign interface itself waits on.
- Fast PBKDF2 built-ins now bound iteration and output counts before host conversion. The unfiltered
  diagnostic regression remains part of the pending durable full gate.

## Grill Log

- **Q:** Does an existing module count as implemented? **A:** No. _Rationale:_ production readiness
  also requires a resolved contract, typed failures, limits, focused regressions, full-suite
  compatibility, documentation, and review. _Rejected:_ closing status rows by file presence.
- **Q:** Can the existing 5k-line branch be described as one reviewable issue? **A:** No.
  _Rationale:_ [[Engineering Delivery]] requires vertical slices below the review-size boundary.
  _Rejected:_ one omnibus PR; discarding the work, which would erase useful implementation without
  establishing a safer replacement.
- **Q:** Should sockets or threads be hidden as ordinary pure operations? **A:** No. _Rationale:_
  they are runtime-owned resources/effects whose failure and lifecycle must stay visible.
  _Rejected:_ token fabrication; silent host exceptions; process-lifetime cleanup only.

## Exact Next Action

Run the unfiltered suite on a host with memory and disk headroom and record the result; that is the
only outstanding gate for everything already implemented. Then decide the `Std.Db` and
`Std.Http.Server` split, which is an API question rather than a mechanical one.

## Referenced by

[[handoffs/_MOC]] · [[architecture/STDLIB]] · [[architecture/SEMANTICS]] · [[Engineering Delivery]]
