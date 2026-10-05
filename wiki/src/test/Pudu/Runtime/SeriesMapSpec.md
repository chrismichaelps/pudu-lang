---
type: module
path: "@root/test/Pudu/Runtime/SeriesMapSpec.hs"
fidelity: Active
tags: [module, test, runtime, performance]
aliases: [Runtime Series Map Tests]
---

# Runtime Series Map Tests

## Purpose and interface

`testSeriesMaps :: IO Property` executes generated persistent insertion histories
against ordinary strict IntMap. [[Eval Test Coordinator]] registers the family;
[[Pudu Test Cabal Manifest]] registers the actual module.

## Algorithm and invariants

Check original touched values, lookup probes, ascending contents and all retained
snapshots after each insertion. Payload tuples retain a representative beside the
numeric count; duplicate combinations take the incoming representative. Exact Eq
of the entire tuple is the representation-equivalence predicate. Generate arbitrary
keys/payloads, with compressible prefixes in both directions followed by gaps,
duplicate replacements and mixed payloads. Explicit cases cover out-of-order
promotion, crossing zero, missing congruence positions, huge strides, host min/max,
sparse points later touched at an adjacent endpoint, and count-one runs.
Structural stored-entry assertions prove long ascending/descending series use one
base payload and sparse edits add only touched storage. No timing threshold.

## Failures and negative logic

No partial indexing, production constructor access or semantic equality that drops
representatives. Every expected map is independently built through ordinary IntMap;
a final-only comparison cannot prove old snapshots or duplicate precedence.

## Grill Log

- **Q:** Test one favorable numeric run only? **A:** No. Generated mixed operations
  and explicit signed-boundary/gap/duplicate histories compare to an independent
  map oracle, including all snapshots and exact touched values.
- **Q:** Assert host elapsed time in tests? **A:** No. Structural entry counts prove
  compression deterministically; the unchanged benchmark suite measures time/RSS.

## Dependencies and consumers

Requires [[Runtime Series Map]], strict IntMap and QuickCheck. Consumed by
[[Eval Test Coordinator]]. No Pudu syntax or diagnostic is introduced here;
[[Eval Data Tests]] retain runtime kind/overflow/ordinary-map diagnostic evidence.

## Referenced by

[[src/_MOC]] · [[Runtime Series Map]] · [[Eval Test Coordinator]] ·
[[Pudu Test Cabal Manifest]]
