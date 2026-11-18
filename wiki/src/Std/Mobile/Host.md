---
type: module
path: "@root/lib/Std/Mobile/Host.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, foreign]
aliases: [Std Mobile Host]
---

# Std Mobile Host

## Purpose and interface

Platform module of the mobile stack. It holds the foreign declarations of the host ABI, so [[Std Mobile View]] stays pure, as [[Native Application UI]] requires for portable UI.

Exports:
- `apply(stream: Bytes) -> ()`: hands a nonempty commit to `pudu_ui_apply(const void *stream, uint64_t length)` in a single foreign call. An empty stream returns immediately.
- `eventDetail() -> UInt32`: calls `pudu_ui_event_detail()` and returns the detail word of the last event handed out.
- `eventWordCount() -> UInt32`: calls `pudu_ui_event_word_count()` and returns how many words the last event carries.
- `eventWord(index: UInt32) -> UInt32`: calls `pudu_ui_event_word(index)` and returns that word of the last event. An index past the count reads zero.
- `wait() -> View.Event`: calls `pudu_ui_wait()` and decodes its 64-bit result. When `View.carriesText` says the event carries text, it fetches that text through `pudu_ui_event_text`; when `View.carriesDetail` says it carries a detail, it fetches the word through `eventDetail`. When `View.carriesWords` says the event is measured, it also fetches its words through `eventWordCount` and `eventWord`, each signed with `View.signed`. It then decodes with `View.eventWithWords`, which takes the measured, detailed or plain path by kind. The text is empty when the event carries none.

## Invariants

- Each nonempty commit crosses the boundary once. One `apply` carries the whole stream, never one call per instruction.
- Every call runs on the thread that runs the program. The host adapter [[iOS Host Adapter]] keeps its controls on that thread.
- `wait` returns one event per call. Events queued while no call is waiting are delivered by later waits in the order the controls queued them.
- A detail word is read only after the wait that produced its event, and before the next wait.
- Words are read only for the measured kinds, after the wait that produced their event and before the next wait.
- The declarations of this module are the only foreign declarations in the mobile library.

## Negative Logic

- No platform callback enters Pudu. No exported function receives events.
- The text of an event is read only when `carriesText` asks for it; a tap or toggle never costs a text call.
- The detail word is read only when `carriesDetail` asks for it; no other event costs a detail call.
- Words are read only when `carriesWords` asks for them; a tap, a toggle or a text change costs no word call.
- No validation of the stream here. A malformed stream is refused by the host adapter, which ends the process with a message naming the defect.
- No node table and no control handles; those live in the host.
- No timeout on `wait`. The loop ends on a `Stopped` event.

## Dependencies and consumers

Depends on [[Std Mobile View]] for `Event`, `event`, `eventWithDetail`, `eventWithWords`, `signed`, `carriesText`, `carriesWords` and `carriesDetail`. Consumers: [[Native Counter Example]], [[Native Form Example]], [[Native Catalog Example]] and [[Native Showcase Example]]. The host side is [[iOS Host Adapter]], which defines `pudu_ui_apply`, `pudu_ui_wait`, `pudu_ui_event_text` and `pudu_ui_event_detail`.

## Resolved Grill Log

- **Q:** Why does Pudu wait for events instead of the platform calling into Pudu? **A:** The model is a local of the entry's loop, and the language has no global mutable state. A blocking wait keeps every Pudu call on the one thread that owns the runtime and needs no reentry. _Rejected:_ platform callbacks into exported functions for events.
- **Q:** Why one crossing per commit? **A:** A stream is one ordered batch, so the cost of the boundary does not grow with the size of the tree. _Rejected:_ one foreign call per control or per property.

- **Q:** Does an empty stream need a platform apply? **A:** It carries no mutation and needs no boundary crossing.

- **Q:** Why a separate detail call rather than a wider event word? **A:** Only one kind carries a detail, and a separate call keeps the common tap and toggle events a single crossing. _Rejected:_ widening the 64-bit event value.

- **Q:** Why read words only for the measured kinds? **A:** Most events carry no words, so a plain tap or toggle keeps its single crossing. _Rejected:_ a word call for every event.
- **Q:** Why sign the words in the program rather than in the host? **A:** The host sends the bits of each value, and the program reads them as two's complement. The sign is then decided by the one function that reads a word, not by each handler.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[iOS Host Adapter]] · [[Native First Light Delivery]] · [[Native Controls Delivery]] · [[Native iOS Recycling Delivery]]
