---
type: module
path: "@root/cbits/pudu_ios_events.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Events]
---

# iOS Host Events

## Purpose and interface

Private event queue of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it alongside the host translation unit and the other private headers ([[Native Toolchain Host Sources]]). It owns the queue of control events, the text and detail each event carries, and the wait that hands them to the program. The queue is its own responsibility, so the host file stays within its line budget as list support is added.

The header provides `pudu_queue(kind, tag, text, detail)`, which appends an event, and the wait and text accessors that [[Std Mobile Host]] calls through `pudu_ui_wait`, `pudu_ui_event_text` and `pudu_ui_event_detail`.

## Behavior

- Each queued event holds its 64-bit value (kind in the high 32 bits, tag in the low 32 bits), the text it carries, and its detail word. An event without text or detail stores an empty text or zero.
- `pudu_ui_wait` runs the main run loop in the default mode until an event is queued, then hands out the oldest.
- `pudu_ui_event_text` and `pudu_ui_event_detail` return the text and detail of the last event handed out. Both stay valid until the next wait.
- Events are handed out in the order the controls queued them.
- The event kind constants live in this header: tapped 1, stopped 2, changed 3, switched on 4, switched off 5, reached 8. The controls header [[iOS Host Controls]] queues them by these names.

## Invariants

- The queue is touched only on the thread that runs the program, as every call of [[iOS Host Adapter]] is.
- A text or detail accessor answers the last event handed out and never a queued one.

## Negative Logic

- No event is dropped and none is repeated by this header; de-duplication of scroll reports is the list's decision in [[iOS Host List]].
- No application logic. The header never reads a tag's meaning.
- No retry or buffering across process exit.

## Dependencies and consumers

Depends on Foundation for the run loop. Included by [[iOS Host Adapter]]. Its values are decoded by [[Std Mobile View]] through [[Std Mobile Host]]. Staged by [[Backend Toolchain App]] and listed in [[Native Toolchain Host Sources]].

## Resolved Grill Log

- **Q:** Why a separate header? **A:** The queue is its own responsibility, and the host file must stay within its line budget as list support is added.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[iOS Host List]] · [[Native iOS Recycling Delivery]]
