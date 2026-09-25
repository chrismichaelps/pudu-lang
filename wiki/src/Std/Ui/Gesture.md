---
type: module
path: "@root/lib/Std/Ui/Gesture.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, gestures, pointer]
aliases: [Std Ui Gesture]
---

# Std Ui Gesture

## Purpose and interface

Gesture recognition as a pure state machine over pointer phases.

Exports: `type Phase = Down | Move | Up`, `type Gesture = Tap | LongPress | DragStarted | Dragged |
DragEnded`, `type Tracker`, `tracker()`, `feed(tracker, phase, point, time)`, `tick(tracker, time)`,
`recognize(phases)`, `inside(frame, point)`.

## Semantics

- A contact that travels no further than the slop (4 pixels) and lifts is a tap at its down point.
- Travelling past the slop starts a drag; every later move reports `Dragged(start, current)` and the
  release reports `DragEnded(start, end)`.
- A contact held still past the hold time (500 ms) is one long press; `tick` delivers it without
  waiting for another phase, and its release is not also a tap.
- A release far from its down with no move in between is neither, because nothing shows the path.

## Grill Log

- **Q:** Callbacks attached to views? **A:** No. _Rationale:_ recognition is a function of phases and
  time, so a gesture is testable from a list of tuples and the tracker can live in the screen's
  state. _Rejected:_ per-view gesture handlers.
- **Q:** Why time from the adapter? **A:** A long press is defined by elapsed time; timestamps taken
  when the event happened stay correct when the program drains input late.

## Dependencies and consumers

- Depends on [[Std Ui Canvas]].
- Consumed by [[Std Ui Controls]] `slid` and programs reading [[Std Ui Desktop]] `Pointer` signals.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
