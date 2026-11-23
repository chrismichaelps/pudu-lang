---
type: module
path: "@root/lib/Std/Mobile/Paging.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, paging]
aliases: [Std Mobile Paging]
---

# Std Mobile Paging

## Purpose and interface

Pure paging helper (#989). The module holds `windowStart`, moved unchanged from [[Std Mobile View]] to keep the view under the source size limit. The view reconciler does not call it. The module performs no I/O and imports nothing.

Exports:
- `windowStart(visible: UInt32, total: UInt32, size: UInt32) -> UInt32`: the first index of a window of `size` items that places `visible` a quarter of the window from its start, clamped so the window never runs past `total`.

## Behavior

- The start is `visible` minus a quarter of `size`, or 0 when that is negative.
- A window that would extend past the end is moved back so it ends at the last item; with `total` at or below `size` the start is 0.
- Examples checked by [[Uses Mobile List]]: (0, 100, 20) is 0; (50, 100, 20) is 45; (95, 100, 20) is 80; (3, 10, 20) is 0.

## Invariants

- The result is never greater than `total - size`, or 0 when `total` does not exceed `size`.
- The function has no state and no effect.

## Negative Logic

- No list rendering. The function returns an index; the caller decides what to draw.
- No fetching. A window of items that is not loaded is the caller's concern.

## Dependencies and consumers

Depends on no other module. Consumers: the recycling catalog [[Native Catalog Example]] and the stdlib fixture [[Uses Mobile List]], which import `windowStart` from this module.

## Resolved Grill Log

- **Q:** Why does this function live in its own module rather than in the view? **A:** The view reconciler must stay under the 500-line limit, and the helper is pure and has no use inside it. A separate module keeps the helper's checks with it. _Rejected:_ raising the limit for the view.
- **Q:** Why is the function moved unchanged? **A:** Its behavior is already checked by the list fixture. A move with no change keeps those checks valid without a new expectation.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Native Catalog Example]] · [[Uses Mobile List]] · [[NATIVE-MOBILE]]
