---
type: module
path: "@root/lib/Std/Desktop/Chrome.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, webview]
aliases: [Std Desktop Chrome]
---

# Std Desktop Chrome

## Purpose and interface

What the run loop knows about its windows beyond their views. `Tracked` holds each window's state,
scale and placement and the system theme; `observe` folds one event into it and answers the
frontend events it causes; `stateJson` answers `window.state()`; `windowCall` answers the reserved
`pudu:window` command; `restore` and `remember` read and write remembered placements.

## Semantics

- Window state, scale and theme changes reach every view of the window as `pudu:window-state`
  (and `pudu:theme` for the theme); inspector changes reach their view as `pudu:devtools`; file
  drops reach their view as `pudu:drop` with `phase` `enter`, `over`, `drop` or `leave`.
- `windowCall` reads `{ action, values }`, refuses it unless a capability grants `window:<action>`
  to the view and origin, builds its record through [[Std Desktop Window]], and answers the window's
  state for `state`; `close` is answered as a close request the loop carries out.
- Placements are kept by window label under the application's preferences
  ([[Std Ui Preferences]]) as `window.<label>`; a remembered placement replaces the plan's size and
  position when the window opens. A placement is only remembered from events the platform reported.

## Grill Log

- **Q:** Why does the program, not the adapter, remember placements? **A:** The program owns which
  windows exist and their labels; the adapter only knows numbers that change between runs.

## Dependencies and consumers

Uses [[Std Desktop Webview]], [[Std Desktop Window]], [[Std Desktop Capability]],
[[Std Desktop Ipc]], [[Std Desktop Protocol]], [[Std Ui Preferences]] and [[Std Json]]. Consumed by
[[Std Desktop App]].

## Referenced by

[[src/Std/_MOC]]

Resolved Grill Log: window action scopes are checked using the JSON values before generating a
record. Close requires zero values and participates in the same validation as other actions.

Resolved Grill Log: window values must be a JSON array of strings; malformed input is InvalidArguments (400), including malformed close calls.

Resolved Grill Log: `stateJson` and the frontend state query return the last observed backend snapshot; the native state command also refreshes subsequent events. Concurrent calls do not synchronously drain native events.

Resolved Grill Log: view-local inspector and drop events queued before a view closes are ignored
when their target is absent from the current holders; late events must not send commands to a
released native view while another window remains open.
