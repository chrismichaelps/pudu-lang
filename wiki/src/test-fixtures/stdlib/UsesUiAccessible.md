---
type: module
path: "@root/test-fixtures/stdlib/UsesUiAccessible.pudu"
fidelity: Active
tags: [module, fixture, ui, accessibility]
aliases: [Uses Ui Accessible]
---

# Uses Ui Accessible

## Purpose

Reach every export of [[Std Ui Accessible]] and the accessibility exports of [[Std Ui Desktop]].
Without a window: every role's name; a snapshot of a laid-out screen that keeps reading order,
parents, frames, and names, marks only the focused control, and turns tabs and newlines in a name
into spaces; a focus tag naming a non-control or nothing marking no node; multi-byte names that
survive the round trip; and each refusal `decode` makes, naming its record.

When a run sets `PUDU_DESKTOP_DRIVE=1` it also opens a real window, exposes the layout, pumps once,
and reads back the platform's report, which must hold the same nodes, platform roles, names, frames,
and focus.

## Grill Log

- **Q:** Open the window in every suite run? **A:** No. _Rationale:_ build agents may have no window
  server. _Accepted:_ the pure encoding in the suite, the live report behind the variable a manual
  macOS run sets, as the clipboard check is.

## Referenced by

[[Std Ui Accessible]] · [[Std Ui Desktop]] · [[Eval Service Spec]]
