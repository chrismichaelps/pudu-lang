---
type: module
path: "@root/lib/Std/Mobile/Decode.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile Decode]
---

# Std Mobile Decode

## Purpose and interface

Pure decoding of the events a host queues. A host wait returns one 64-bit value, the kind in the high 32 bits and the tag in the low 32 bits, and some kinds carry a text, a detail word or signed words beside it. This module turns those values into the `Event` type of [[Std Mobile View]]. It was split out of View unchanged so View stays under the line budget. [[Std Mobile Host]] calls it from `wait`.

Exports:
- The event kind constants and the constructor tables `EVENTS`, `DETAILED` and `MEASURED`.
- `carriesText(raw: UInt64) -> Bool`: whether the event's text must be fetched before `event` is called.
- `carriesDetail(raw: UInt64) -> Bool`: whether the event's kind is listed in `DETAILED` or `MEASURED`, so one more word must be fetched before decoding.
- `carriesWords(raw: UInt64) -> Bool`: whether the event's kind is listed in `MEASURED`, so its signed words must be fetched before decoding.
- `event(raw: UInt64, text: Str) -> Event`: decodes one value with the text the host fetched for it.
- `eventWithDetail(raw: UInt64, text: Str, detail: UInt32) -> Event`: decodes a detailed event with the word the host fetched for it.
- `eventWithWords(raw: UInt64, text: Str, detail: UInt32, values: Array[Int32]) -> Event`: decodes an event with its detail word and words. A measured kind decodes through `MEASURED`, a detailed kind through `DETAILED`, and every other kind through `event`.
- `signed(word: UInt32) -> Int32`: the two's complement reading of a host word.

Event kinds, with the constructor each decodes to:
- 1 `Tapped(tag)`, 2 `Stopped`, 3 `Changed(tag, text)`, 4 `Toggled(tag, true)`, 5 `Toggled(tag, false)`.
- 8 `Reached(tag, detail)`, the first visible index of a list.
- 9 `Gestured`, measured. 10 `Chose`, 11 `Resized`, 12 `Lifecycle`, 13 `Picked`, detailed or measured as listed in the tables.
- 14 `Valued(tag, Int32)`: the detail word is the value as Int32 bits. Slider, stepper, segments, wheel and pages report it.
- 15 `Colored(tag, UInt32)`: the detail word is packed RGBA. The color well reports it.
- 16 `Dated(tag, Int64)`: two words, high then low. The seconds are `signed(high) * 2^32 + unsigned(low)`. Fewer than two words reads as `Stopped`.

## Invariants

- Pure: the module declares no foreign function. Platform calls live in [[Std Mobile Host]].
- Decoding goes through the constant tables `EVENTS`, `DETAILED` and `MEASURED`. An unknown kind reads as `Stopped`.
- `carriesText` is true only for kind 3.
- `carriesDetail` is true only for the kinds in `DETAILED` and `MEASURED`.
- `carriesWords` is true only for the kinds in `MEASURED`.
- `event` never fails. A measured or detailed kind whose words or detail do not decode reads as `Stopped`.
- Event kind is read from the high 32 bits and the tag from the low 32 bits.

## Negative Logic

- No fetch. The module never calls the host; the caller fetches text, detail and words as the `carries` functions ask.
- No decoding of a detail for a kind outside `DETAILED` and `MEASURED`.
- No text in the 64-bit value. Only `Changed` carries text, and the host supplies it.
- No I/O and no platform call.

## Dependencies and consumers

Depends on [[Std Mobile View]] for the `Event` type. Consumers: [[Std Mobile Host]], whose `wait` decodes through these functions; [[Std Mobile View]], which re-exports none of them; and the fixtures [[Uses Mobile View]], [[Uses Mobile List]] and [[Uses Mobile Capabilities]], which check the decoding of each kind.

## Resolved Grill Log

- **Q:** Why move decoding out of View? **A:** Decoding depends only on the Event type; moving it is a pure split with no behavior change, and frees the budget for the new cases.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Host]] · [[Native iOS Controls Delivery]]
