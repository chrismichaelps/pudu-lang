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

The header provides `pudu_queue(kind, tag, text, detail)`, which appends an event, and the wait and text accessors that [[Std Mobile Host]] calls through `pudu_ui_wait`, `pudu_ui_event_text` and `pudu_ui_event_detail`, and the word accessors `pudu_ui_event_word_count` and `pudu_ui_event_word`.

## Behavior

- Each queued event holds its 64-bit value (kind in the high 32 bits, tag in the low 32 bits), the text it carries, its detail word, and its word channel. An event without text, detail or words stores an empty text, zero, and no words.
- DESCRIBED (32) and NETWORKED (33) are queued by [[pudu-ios-device]]. DESCRIBED carries its five text lines and the text scale as its detail word; NETWORKED carries the link code as its detail word (#983).
- LOCATED (34) is queued by [[pudu-ios-location]]. Its tag is the LOCATE's tag, or 0 for a TRACK report. Its detail word is 1 with four words for a position, or 0 with no words when no position is available (#986).
- `pudu_ui_wait` runs the main run loop in the default mode until an event is queued, then hands out the oldest.
- `pudu_ui_event_text` and `pudu_ui_event_detail` return the text and detail of the last event handed out. Both stay valid until the next wait.
- Events are handed out in the order the controls queued them.
- The event kind constants live in this header: tapped 1, stopped 2, changed 3, switched on 4, switched off 5, reached 8, gestured 9, chose 10, resized 11, lifecycle 12, picked 13, popped 14, dismissed 15, refreshed 16, insets 17, fetched 18, woke 19, memory 20. The controls header [[iOS Host Controls]], the capability headers and [[pudu_ios_navigation.h]] queue them by these names.
- `pudu_unqueue(kind)` drops every queued event of `kind` that the program has not read. The navigation header calls it for popped and dismissed events when a newer NAVIGATE arrives, so a report about the replaced presentation is never delivered.
- `pudu_before_wait` is a hook run at the start of each `pudu_ui_wait`, before the queue is read. A header that must act once the program asks for its next event registers a call here; [[iOS Host Refresh]] ends an unanswered pull this way.

## Word channel

Measured events, gestured (9), resized (11), insets (17) and fetched (18), carry up to four signed words beside the detail word. Fetched events also carry text, the response body. [[iOS Host Fetch]] queues fetched, woke and memory events through this header. `pudu_queue_words` appends them, and any count above four is cut to four. `pudu_ui_event_word_count` returns how many words the last event handed out carries, and `pudu_ui_event_word(index)` returns word `index` as its 32 bits. An index past the count reads zero. The words stay valid until the next wait. [[Std Mobile Host]] reads them only for the kinds that [[Std Mobile View]] lists as measured.

## Invariants

- The queue is touched only on the thread that runs the program, as every call of [[iOS Host Adapter]] is.
- A text or detail accessor answers the last event handed out and never a queued one.

## Negative Logic

- No event is dropped and none is repeated by this header; de-duplication of scroll reports is the list's decision in [[iOS Host List]].
- No application logic. The header never reads a tag's meaning.
- No retry or buffering across process exit.

## Dependencies and consumers

Depends on Foundation for the run loop. Included by [[iOS Host Adapter]]. Its values are decoded by [[Std Mobile View]] through [[Std Mobile Host]]. Staged by [[Backend Toolchain App]] and listed in [[Native Toolchain Host Sources]].

## Resolved Grill Log for #935

The list self-test inspects pending Reached events for its tag before it
queues the stop. The host still delivers events in FIFO order.

## Resolved Grill Log

- **Q:** Why a separate header? **A:** The queue is its own responsibility, and the host file must stay within its line budget as list support is added.

## Services (#989)

Events 35 to 41 (NOTIFIED, AUTHENTICATED, BROWSED, SPOKE, POWERED, SENSED and IMAGE_PICKED) are queued through the event channel. IMAGE_PICKED carries its file path on the text channel, as CHANGED and PASTED do. The decoders are in [[Std Mobile Events]].

## Pickers and system touches (#991)

CONTACT_PICKED (45) and FILED (46) are queued by [[pudu-ios-pick]] through [[iOS Host Events]].

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[iOS Host List]] · [[Native iOS Recycling Delivery]] · [[iOS Host Refresh]]
