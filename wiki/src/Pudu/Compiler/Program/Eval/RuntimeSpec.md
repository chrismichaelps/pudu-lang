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

Consumes [[Uses Crypto All]], [[Uses Concurrent]], and the other runtime fixtures it registers.

[[src/_MOC]] · [[architecture/DELIVERY]]
