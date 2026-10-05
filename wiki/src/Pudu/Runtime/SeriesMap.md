---
type: module
path: "@root/src/Pudu/Runtime/SeriesMap.hs"
fidelity: Active
tags: [module, runtime, performance, persistent]
aliases: [Runtime Series Map]
---

# Runtime Series Map

## Purpose and interface

A pure persistent Int-keyed map compresses a constant-payload arithmetic series
while retaining arbitrary points and overrides in a strict IntMap. This internal
storage boundary has no evaluator, syntax, diagnostic, IO or package dependency
beyond containers/base. Export abstract `SeriesMap`, `empty`, `singleton`,
`lookup`, `insertLookupWithKey`, `toAscList` and `storedEntryCount`.
`storedEntryCount` counts stored payload entries for deterministic structural evidence;
it does not measure bytes or represented cardinality and is not a hot-path API.
A derived Show instance supports internal Value debugging; public rendering
still consumes the ordered view.

`insertLookupWithKey` takes a caller-supplied representation-equivalence predicate,
a key-aware duplicate combiner, incoming key/payload and existing map. It returns
the original touched payload and new map, as strict IntMap insertion does. The
predicate must prove payloads interchangeable, including retained representation;
semantic equality that erases spelling, kinds or ownership is insufficient.

## Algorithm and invariants

Points start as an IntMap with cardinality capped at four. Only a three-point
map is inspected for strictly ascending, equal positive gaps and interchangeable
payloads. The cap avoids linear IntMap.size on each insertion. Promotion stores
first/last endpoints, positive host-Int stride, one strict base payload and sparse
points. Once promoted, exact adjacent base-valued insertions extend either end.
Arbitrary new points and all duplicate combinations remain sparse. Sparse lookup
precedes series membership; an existing sparse endpoint is a duplicate, never a
fresh extension. No existing representative is erased unless the supplied predicate
proves interchangeable storage.

Membership requires signed endpoint inclusion before unsigned Word subtraction
and congruence. Ordered endpoint distances fit Word even when signed subtraction
would overflow. Promotion checks positive gaps before converting Word to Int.
Enumeration merges the ascending series and sparse points, replacing equal series
keys with their override; advance only before the last endpoint, where the proven
series invariant bounds the next signed addition. Every snapshot remains immutable.
The ordered view is lazy; storage construction never enumerates a long series.

## Failure and negative logic

No deletion, callbacks outside duplicate insertion, implicit mutation, raw pointers,
public language collection or eager view materialization. Random/uncompressible
inputs remain ordinary points, or sparse additions to an existing proven series.
Do not recognize benchmark names, key distributions, modulo constants or sizes.
A representation-equivalence predicate is a private caller contract, not an
inference from generic Eq. No native speed or universal compression claim.

## Dependencies and consumers

Requires base and strict IntMap. [[Eval Value]] uses ordered enumeration;
[[Eval MultiMap]] supplies the narrow exact platform-kind/count-one predicate.
[[Runtime Series Map Tests]] compare every snapshot and touched result to ordinary
IntMap and verify structural compression independent of host timings.

## Grill Log

- **Q:** Compress by numeric equality alone? **A:** No. The caller proves exact
  interchangeable payloads; retained representatives and duplicate results remain
  sparse. MultiMap admits only platform pairs with platform count one.
- **Q:** Infer a complete series from two points? **A:** Wait for three equal-gap
  points. Every member is already present before promotion; extension inserts one
  adjacent point only. No absent key is invented.
- **Q:** Use signed endpoint subtraction? **A:** No. Ordered distance uses Word,
  preserving both host boundaries and ranges crossing zero without overflow.
- **Q:** Add overlapping runs with predecessor lookup? **A:** No. One proven series
  plus sparse points avoids losing members through overlaps or gaps. Compression
  benefit depends on input; arbitrary values retain ordinary map behavior.
- **Q:** Check map size on each insertion? **A:** No. A capped small cardinality
  tracks the sole promotion opportunity without repeated linear traversal.

## Referenced by

[[src/_MOC]] · [[Eval Value]] · [[Eval MultiMap]] · [[Pudu Cabal Manifest]] ·
[[Runtime Series Map Tests]]
