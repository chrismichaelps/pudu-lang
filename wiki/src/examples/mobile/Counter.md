---
type: module
path: "@root/examples/mobile/Counter.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native]
aliases: [Native Counter Example]
---

# Native Counter Example

## Purpose and interface

The Phase 1 application of [[Pudu Native]]: a counter built only from Pudu and run on the iOS simulator through the [[iOS Host Adapter]]. It is the smallest program that uses the whole loop: state, view, stream, event and the change path.

- Model: an `Int` count, starting at 0.
- View: a column holding the label `Count: {count}` and the button `Add one`, tagged 1.
- Entry: builds the view and applies its stream with `View.build`, then loops on `Host.wait()`. A `Tapped` event with tag 1 increments the count, builds the next view, applies `View.changes` from the shown view to the next one, and continues. A `Stopped` event returns 0.

## Invariants

- The shown view is always the last view applied, so every `changes` call starts from what the screen displays.
- Only the button's tag selects the increment. The count changes only on that tag.
- The entry returns 0 on `Stopped`, and the status is the process status.

## Negative Logic

- No network, no storage, no timers, and no foreign call of its own. Platform access goes through [[Std Mobile Host]].
- No keyed regions and no removal. The shape never changes, so the change path always emits TEXT only.
- No handling of other events. A tag other than 1 does not exist in this program.

## Dependencies and consumers

Depends on [[Std Mobile View]] and [[Std Mobile Host]]. Run by the simulator job described in [[iOS Simulator Run]] and checked by the fixture [[Uses Mobile View]].

## Resolved Grill Log

- **Q:** Why a counter for phase 1? **A:** It exercises build, change, wait and the stop path with one state value, so a failure points at the mobile stack and not at the application. _Rejected:_ a list application, which needs keyed regions not yet defined.

## Referenced by

[[src/examples/README]] · [[Native First Light Delivery]]
