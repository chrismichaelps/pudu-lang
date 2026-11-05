---
type: module
path: "@root/test-fixtures/stdlib/UsesIterViews.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
aliases: [UsesIterViews]
tags: [module, test, fixture]
---
# UsesIterViews

## Purpose and interface
main returns six assertion groups proving chunk, slide, adjacent grouping, flattening,
reverse and Cartesian products via [[Std Iter Views]].

## Algorithm and invariants
Check empty/singleton sources, partial chunks and complete windows, clamped widths,
restartability, nested empty sequences, lexicographic product ordering and map composition.
Use a source with observable advance calls to prove constructors are lazy, bounded
prefixes avoid later work, each input item is read once and completed states stop.

## Resolved Grill Log
Use explicit expected arrays and call counts; run tree and compiled modes and register
through [[Program View Spec]]. No timing or host-specific allocation threshold.

## Referenced by
[[Program View Spec]] · [[Std Iter Views]]
