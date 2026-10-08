---
type: module
path: "@root/test-fixtures/derive/Expand.expected"
fidelity: Active
tags: [fixture, derive, expansion]
aliases: [Derive Expand Expected]
---
# Derive Expand Expected

## Purpose and interface

Exact printed expansion of [[Derive Expand Fixture]], compared by [[Derive Library Spec]].
It records ordinary implementations in source order, with generated provenance comments.

## Algorithm and resolved Grill Log

Preserve the fixed expansion text. For #457, three optional text decoder calls explicitly select
Str; the complete optional owner previously disappeared from printed output. This selection
changes no requested capability or result and remains ordinary Pudu syntax. Inspect that exact
three-call delta before updating the snapshot; no other textual change is admitted.

## Referenced by

[[Derive Expand Fixture]] · [[Derive Library Spec]] · [[src/_MOC]]
