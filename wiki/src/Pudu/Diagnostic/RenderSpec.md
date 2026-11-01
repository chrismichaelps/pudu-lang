---
type: module
path: "@root/test/Pudu/Diagnostic/RenderSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Diagnostic Render Properties]
tags: [module, test, diagnostics]
---
# Diagnostic Render Properties

## Purpose and interface

renderProperties :: [(String, IO Property)] is registered by the existing test
runner and test package. Prove human diagnostic rendering through public compile,
diagnostic, source and rendering APIs. No private renderer state is mocked.

## Algorithm and invariants

Existing properties pin headline/location/excerpt/caret layout, related-context
and help cardinality, plain style, interactive preamble mapping, summary counts
and tab alignment. New source-context properties construct two immutable sources
with deliberately different line layouts and one diagnostic with a foreign note.
Verify the explicit loaded-source map gives the producer's actual coordinates,
that consumer-only layout changes cannot change that note, and that missing or
stale same-name snapshots give honest filename/offset without foreign excerpts.
Interactive display names/first-line offsets apply solely to primary spans.
Keep all ordinary same-source output assertions stable.

## Negative logic

No filesystem/network access, whole-output snapshots hiding a changed coordinate,
invented diagnostics, source-name-only snapshot matching or discarded failures.
Source spans and diagnostic construction use the public checked APIs.

## Resolved Grill Log

Snapshot identity is the admission proof for coordinates. Filename equality alone
cannot distinguish two editor versions. Test available, absent and stale sources
independently, as well as the real CLI integration in [[Sum Owner Gate]].
See [[Diagnostic Source Delivery]].

## Referenced by

[[Diagnostic Render]] · [[Pudu Test Cabal Manifest]] · [[src/_MOC]] · [[Diagnostic Source Delivery]]
