---
type: module
path: "@root/test/Pudu/GeneratedIdentitySpec.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, derive]
aliases: [Generated Identity Spec]
---

# Generated Identity Spec

## Purpose and interface

`generatedIdentityProperties` tests compact generated origins, authored bounds,
source identity, map distinction, checker places and deduplication, diagnostic
notes, editor projections, and conservative persistent cache misses.

## Algorithm and edge cases

Construct valid spans from two ingested snapshots and two request sites. Reuse
authored offsets with different ordinals and verify complete facts stay separate.
Merge equal and incompatible origins. Ordinary spans still round-trip to a new
snapshot; generated and foreign same-name spans refuse persistence. Regeneration
keeps a bounded authored origin rather than a recursive chain.

## Negative logic

No manufactured invalid offsets, external filesystem fixtures or runtime timing
thresholds. Assert structured products and diagnostic related locations.

## Grill Log

- **Q:** Test only Span equality? **A:** No; exercise the actual checker state and
  serialization boundaries. _Rationale:_ offset projection can lose identity after
  the source layer succeeds. _Rejected:_ constructor-mirroring tests alone.

## Referenced by

[[src/_MOC]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]] · [[Source]]
