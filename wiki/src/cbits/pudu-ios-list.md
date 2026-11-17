---
type: module
path: "@root/cbits/pudu_ios_list.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host List]
---

# iOS Host List

## Purpose and interface

Private list and grid implementation of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the LIST kind, the RANGE and COLUMNS instructions, the cell layout of a list, and the scroll report that asks the program for the next window. Recycling is its own responsibility, as layout and theming are, which keeps the host file within its line budget.

The header handles two instructions of [[Std Mobile Stream]]: RANGE (24) and COLUMNS (25), and the kind LIST (8).

## Behavior

- A LIST node is a collection view with a compositional layout of `columns` equal-width items and estimated self-sizing heights. The grid group uses the iOS 13 equal-subitem group form, because generated apps target iOS 15.
- Its children are held by a row store: a stack view subclass that records the ordered window rows without displaying them. Because of this, INSERT, MOVE and APPEND keep working unchanged.
- The cell for item index i hosts the view of window row i minus `first`, pinned to the cell's content edges. An index outside the window shows an empty cell until Pudu supplies its row.
- Removing a row node also drops it from its store.
- Any change to a list's rows, range or columns reloads the list once at the end of the commit. The platform reconfigures only visible cells.
- The edge check runs in the list's layout pass, after every scroll and size change; the list is not its own scroll delegate. The edge margin is a quarter of the window, but never more than half of what the window holds beyond the visible span, so a window too small for the screen cannot alternate between its two edges. When the first visible index falls within the edge margin of the window start, and the window does not start at 0, or the last visible index falls within the edge margin of its end, and the window does not reach `total`, it queues event kind 8 with the list's tag and the first visible index as the detail. It never repeats the same index twice in a row.
- A list shown as the root fills the safe-area region like a scroll viewport.
- Self-test `PUDU_UI_LIST_TEST`: scrolls the first list to its last item, waits until that item's cell shows a label, the committed window reaches the end, and its queued Reached events settle, prints `PUDU_LIST reached <label text>`, and prints `PUDU_LIST reused` when fewer cells were ever made than a fifth of the items. It also prints `PUDU_CELLS <made> of <total> items` as a measurement. Then it asks the program to stop.

## Invariants

- Every platform call of this header runs on the thread that runs the program.
- The window rows of a store are in index order, and row i of the store is item `first` plus i.
- A list's reported `Reached` index is always an index of its own visible range.

## Negative Logic

- No row is built here. Pudu builds rows; the header only places and displays them.
- No per-item update. A change reloads the list once rather than updating single cells.
- No placement vocabulary of its own. A second placement instruction is refused; a store keeps the keyed instructions meaningful for a list.
- No event for an index already reported in the previous report.
- No stale content: an empty cell is shown rather than a row from an earlier window.

## Dependencies and consumers

Depends on UIKit. Included by [[iOS Host Adapter]]. Its instructions are encoded by [[Std Mobile Stream]] and [[Std Mobile View]]. Reports through the event queue of [[iOS Host Events]]. Staged by [[Backend Toolchain App]] and listed in [[Native Toolchain Host Sources]].

## Resolved Grill Log

- **Q:** Why a hidden row store instead of a new placement instruction? **A:** The keyed reconciler already emits INSERT, MOVE and REMOVE; a store keeps them meaningful for a list. _Rejected:_ a second placement vocabulary.
- **Q:** Why reload the whole list rather than single cells? **A:** A reload reconfigures only visible cells, and a commit already batches every change; per-item updates are a later optimization.
- **Q:** Why an empty cell for an index outside the window? **A:** It is visible only if scrolling outruns the program, and it never shows stale content.
- **Q:** Why check edges in the layout pass? **A:** It runs after every scroll and size change with no self-delegation.
- **Q:** Why bound the margin by the visible span? **A:** Testing showed a 60-item window on a screen showing about 50 items alternating between its edges at the end of the list. The bound turns a too-small window into slower updates instead of an endless exchange.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[iOS Host Events]] · [[Native Catalog Example]] · [[Native iOS Recycling Delivery]]
