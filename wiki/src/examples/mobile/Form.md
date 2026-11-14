---
type: module
path: "@root/examples/mobile/Form.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native]
aliases: [Native Form Example]
---

# Native Form Example

## Purpose and interface

The Phase 2 application of [[Pudu Native]]: a form built only from Pudu and run on the iOS simulator through the [[iOS Host Adapter]]. It exercises named controls, a text field, a toggle and the event payloads that the counter does not use.

- Model: `{ name: Str, subscribed: Bool }`, starting from the name given at launch and not subscribed.
- View: a column holding a named greeting label, `Hello, {name or stranger}` plus ` (subscribed)` when subscribed, a named name field, and a row holding a `Subscribe` toggle and a `Clear` button.
- Entry: mounts the view with `View.mount`, then loops on `Host.wait()`. `Changed` sets the name, `Toggled` sets the subscription and `Tapped` on the Clear tag empties the name and clears the subscription. Each change builds the next view and `View.update` applies it to the mounted tree, which the loop keeps. A `Stopped` event returns 0.

## Invariants

- The mounted tree is always the last tree applied, so every `update` starts from what the screen displays.
- `update` maps each event by its tag. A tag selects one control only, and an event with an unknown tag leaves the model unchanged.
- The field text is the model's name, so the label and the field agree after every event.
- The entry returns 0 on `Stopped`, and the status is the process status.

## Negative Logic

- No network, no storage, no timers, and no foreign call of its own. Platform access goes through [[Std Mobile Host]].
- No keyed regions and no removal. The shape never changes, so every change is an in-place update.
- No validation of the name. An empty name shows `stranger`.

## Dependencies and consumers

Depends on [[Std Mobile View]] and [[Std Mobile Host]]. Run by the simulator job described in [[iOS Simulator Run]] with `PUDU_UI_TYPE=Ada`, and its view is covered by the fixture [[Uses Mobile View]].

## Resolved Grill Log

- **Q:** Why a form for phase 2? **A:** It exercises named controls, text input, toggle state and the payload-carrying events with one model, so a failure points at the control path and not at the application. _Rejected:_ a list application, which needs keyed regions not yet defined.

## Referenced by

[[src/examples/README]] · [[Native Controls Delivery]]
