---
type: module
path: "@root/test/Pudu/Compiler/Program/Eval/RuntimeSpec.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, runtime, evaluation]
aliases: [Runtime Evaluation Spec]
---

# Runtime Evaluation Spec

## Purpose and interface

Runs executable Pudu fixtures for core semantics, numeric widths, effects, standard-library runtime
services, concurrency, files, processes, and cryptography. `testRuntimeEvaluation` loads every fixture
through the program compiler and joins exact returned assertion counts into one QuickCheck property.

## Governance and algorithm

Every counterexample names the observable contract rather than the fixture mechanism. Exact equality
keeps a skipped assertion visible: adding or losing one Pudu branch requires changing the registered
count after inspecting that semantic delta. `UsesCryptoAll` is registered at 59 assertions, including
independent SHA-3/BLAKE2b vectors, RFC 4231 HMAC-SHA512 vectors, constant-time comparison behavior,
secure key/nonce lengths, and authenticated-encryption round trips.

`UsesCronAll` (18), `UsesStatsAll` (27), `UsesDotenvAll` (17), and `UsesTermAll` (13) register the
schedule, statistics, environment-file, and terminal-styling modules, each reaching every export and
its refusals.

[[Uses Concurrent Futures]] (30), [[Uses Concurrent Coordination]] (39), and [[Uses Concurrent Scope]] (7) register the concurrency
modules ([[Std Concurrent Future]], [[Std Concurrent Cancel]], [[Std Concurrent Pool]],
[[Std Concurrent Coordinate]], [[Std Concurrent Retry]]), with crashing work, contention, and
refusals beside the successful paths. Every check is written so its answer does not depend on which
thread got there first.

[[Uses Base32 Pem All]] (30) registers [[Std Base32]] and [[Std Pem]].

## Grill Log

- **Q:** Accept a minimum fixture count? **A:** No. _Rationale:_ one new passing check could hide one
  old check that stopped executing. _Rejected:_ `>=` registration.
- **Q:** Derive digest expectations from the runtime under test? **A:** No. _Rationale:_ two calls to
  the same defective implementation only prove consistency. _Rejected:_ self-generated vectors.
- **Q:** Collapse all runtime fixtures into one Pudu program? **A:** No. _Rationale:_ a failure should
  name its domain and keep source discovery bounded. _Rejected:_ one omnibus fixture.

Resolved Grill Log: fixtures execute through the real program boundary, exact counts expose skipped
branches, and cryptographic expectations originate outside the implementation being checked.

## Referenced by

Consumes [[Uses Crypto All]], [[Uses Concurrent]], [[Uses Concurrent Futures]], [[Uses Concurrent Coordination]], [[Uses Concurrent Scope]], [[Uses Base32 Pem All]], and the other runtime fixtures it registers.

[[src/_MOC]] · [[architecture/DELIVERY]]
