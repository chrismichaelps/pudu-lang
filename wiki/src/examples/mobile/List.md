---
type: module
path: "@root/examples/mobile/List.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native]
aliases: [Native List Example]
---

# Native List Example

## Purpose and interface

The keyed-list application of [[Pudu Native]]: a list built only from Pudu and run on the iOS simulator through the [[iOS Host Adapter]]. It exercises keyed rows, insertion, reorder and the mounted tree that [[Std Mobile View]] keeps between commits.

- Model: `{ draft: Str, items: Array[(UInt32, Str)], made: UInt32 }`. `draft` is the text of the named field, `items` holds each row's id and text, and `made` counts the rows created so far.
- View: a column holding a named field bound to `draft`, a row holding the buttons `Add` and `Reverse`, a count label `{n} items`, and a keyed column of labels, each keyed by its item's id.
- Entry: mounts the view with `View.mount`, then loops on `Host.wait()`. `Changed` sets `draft`. `Tapped` on Add appends the item `{draft} {n}`, where `n` is `made` after it is incremented, and sets its id to the same value. `Tapped` on Reverse reverses `items`. Each change builds the next view and applies `View.update` from the mounted tree. A `Stopped` event returns 0.

## Invariants

- The mounted tree is always the last tree applied, so every `update` starts from what the screen displays.
- An item's id is fixed when it is created and never reused by the program, so a row keeps its identity across reversals.
- The count label equals the number of items.
- The entry returns 0 on `Stopped`, and the status is the process status.

## Negative Logic

- No network, no storage, no timers, and no foreign call of its own. Platform access goes through [[Std Mobile Host]].
- No removal in this program. A removed row would free its id, which is covered by the fixture [[Uses Mobile View]], not here.
- No validation of the draft. An empty draft still appends a row named with the number alone.

## Dependencies and consumers

Depends on [[Std Mobile View]] and [[Std Mobile Host]]. Run by the simulator job described in [[iOS Simulator Run]] with `PUDU_UI_TYPE=Milk`, pressing each button in rounds: each of three rounds presses Add, then Reverse. The expected labels are `3 items`, `Milk 3`, `Milk 1`, `Milk 2`, in screen order.

## Resolved Grill Log

- **Q:** Why key rows by item id instead of position? **A:** Reversing moves every row, and a position key would rebuild each one; an id key moves each row once. _Rejected:_ position keys.
- **Q:** Why a list for this phase? **A:** It exercises keyed insertion and reorder with one model, so a failure points at the reconciler and not at the application. _Rejected:_ a counter with more buttons, which never changes shape.

## Referenced by

[[src/examples/README]] · [[Native Keyed Lists Delivery]]
