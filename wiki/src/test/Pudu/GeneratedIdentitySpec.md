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
Checked-product tests put a generated or foreign span only inside an otherwise
authored function body, with no integer-kind facts to force an eager read. The
collecting cache must remain empty. An ordinary product stores and restores its
complete deferred declaration and body, proving ordinary reuse still works.
Generated integer-kind keys refuse storage even with ordinary syntax.

## Negative logic

No manufactured invalid offsets, external filesystem fixtures or runtime timing
thresholds. Assert structured products and diagnostic related locations.

## Grill Log

- **Q:** Test only Span equality? **A:** No; exercise the actual checker state and
  serialization boundaries. _Rationale:_ offset projection can lose identity after
  the source layer succeeds. _Rejected:_ constructor-mirroring tests alone.

## Referenced by

[[src/_MOC]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]] · [[Source]]
