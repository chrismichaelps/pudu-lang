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
three-call delta before updating that snapshot revision.

## Referenced by

[[Derive Expand Fixture]] · [[Derive Library Spec]] · [[src/_MOC]]

## No-else conditional conformance (#490)

The optional decoder retains the generated literal-true no-else conditional
around its labelled break. Only that three-line expansion changes: a normal
then result must remain unit under [[ADR-0025-if-without-else-unit-results]],
so derive residualization no longer replaces this conditional with a block.
The break still transfers to the same target with the same decoder value.

Resolved Grill Log: inspect the exact expansion diff before refreshing; accept
only the retained conditional wrapper. Rejected: replacing an uninspected
snapshot or changing the decoded result to satisfy expected text.
