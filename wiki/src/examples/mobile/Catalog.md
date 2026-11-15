---
type: module
path: "@root/examples/mobile/Catalog.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native]
aliases: [Native Catalog Example]
---

# Native Catalog Example

## Purpose and interface

A program that shows a recycling grid on the iOS simulator. It mounts a grid of 1,000 items in 3 columns. Each item is a label `Item n` with a 1-based index, keyed by its index, and the program supplies a window of 120 items at a time, at least twice what one screen shows. On `Reached`, it recomputes the window with `windowStart` for the reported first visible index and updates the view. A stop ends the program.

The simulator run sets `PUDU_UI_LIST_TEST` and expects these lines, as described in [[iOS Simulator Run]]:
- `PUDU_LIST reached Item 1000`
- `PUDU_LIST reused`
- The label report lists `Item 881` through `Item 1000`, the final 120 items, in screen order.

## Invariants

- The window never runs past the total: `windowStart` clamps the first index so the window of 120 stays within 1,000 items.
- Each item's key is its index, so a window move reconciles rows by key and keeps the rows still on screen.

## Negative Logic

- No item outside the window is built.
- No event besides `Reached` and `Stopped` is handled.
- The grid is not a catalogue of real content; its labels exist only to be read back by the self-test.

## Dependencies and consumers

Depends on [[Std Mobile View]] for `Recycled`, `windowStart` and `Reached`, [[Std Mobile Host]] for `apply` and `wait`. Hosted by [[iOS Host Adapter]] with the list header [[iOS Host List]] and the event header [[iOS Host Events]].

## Resolved Grill Log

- **Q:** Why 1,000 items? **A:** The count must be well above one screen, so the self-test can show that the cells are reused: fewer cells are made than a fifth of the items. The count is the test's reach, not a limit of the list. Measured on an iPhone 17 simulator (iOS 26.4), a jump from the first item to the last made 100 cells for 1,000 items.
- **Q:** Why a window of 120 rather than the whole list? **A:** A window bounded by the screen keeps each commit proportional to what can be seen; see [[Std Mobile View]]. It holds at least twice one screen, so scrolling reaches the window edge rarely.

## Referenced by

[[src/examples/README]] · [[iOS Simulator Run]] · [[Uses Mobile List]] · [[Native iOS Recycling Delivery]]
