---
type: module
path: "@root/lib/Std/Ui/Virtual.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, lists, performance]
aliases: [Std Ui Virtual]
---

# Std Ui Virtual

## Purpose and interface

Windowing for long lists: which rows a viewport shows, so a view places a screenful of rows rather
than a million.

Exports: `type Window = { first, last, top, height }`, `offsets(heights)`, `visible(count,
rowHeight, viewport, scroll, overscan)`, `visibleOf(offsets, viewport, scroll, overscan)`,
`indexAt(offsets, y)`, `scrollToShow(offsets, index, viewport, scroll)`, `clampScroll`.

## Semantics

- Equal rows are arithmetic; varying rows binary-search their offsets.
- The view renders rows `first..last` inside a spacer of `top` pixels and a content of `height`,
  so scroll range and scroll bar stay exact.
- `scrollToShow` moves as little as possible, which is what keyboard selection needs.

## Grill Log

- **Q:** Measure rows lazily inside layout? **A:** No. _Rationale:_ layout stays a pure function of
  a small view; the caller owns the heights it knows and passes offsets. _Rejected:_ a lazy stack
  that measures during placement.

## Dependencies and consumers

- No dependencies.
- Consumed by list, table, and outline views over [[Std Ui Layout]] scroll nodes.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
