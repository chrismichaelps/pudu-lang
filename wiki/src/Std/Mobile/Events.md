---
type: module
path: "@root/lib/Std/Mobile/Events.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile Events]
---

# Std Mobile Events

## Purpose and interface

Pure decoder of host events. The host hands the program one 64-bit word per event: the kind in the high 32 bits and the tag in the low 32 bits. Some kinds also carry text, one detail word, or up to four signed words, which the host holds until the program fetches them. This module turns that word and those values into a [[Std Mobile View]] `Event`. It is used only by [[Std Mobile Host]], which performs the fetches.

Exports:
- `carriesText(raw: UInt64) -> Bool`: whether the event's text must be fetched before decoding. True only for kind 3.
- `carriesDetail(raw: UInt64) -> Bool`: whether the kind is listed in `DETAILED` or `MEASURED`, so the detail word must be fetched first.
- `carriesWords(raw: UInt64) -> Bool`: whether the kind is listed in `MEASURED`, so its signed words must be fetched first.
- `signed(bits: UInt32) -> Int32`: the two's complement reading of a host word.
- `event(raw: UInt64, text: Str) -> View.Event`: decodes an event that needs no detail or words.
- `eventWithDetail(raw: UInt64, text: Str, detail: UInt32) -> View.Event`: decodes a detailed event with the detail word the host fetched.
- `eventWithWords(raw: UInt64, text: Str, detail: UInt32, values: Array[Int32]) -> View.Event`: decodes an event with its detail word and signed words. A measured kind decodes through `MEASURED`, a detailed kind through `DETAILED`, and every other kind through `event`.

Kind codes: TAPPED 1, Stopped 2 (the host's stop), CHANGED 3, SWITCHED_ON 4, SWITCHED_OFF 5, REACHED 8, GESTURED 9, CHOSE 10, RESIZED 11, LIFECYCLE 12, PICKED 13, POPPED 14, DISMISSED 15, REFRESHED 16, INSETS 17.

Event payloads by kind:
- POPPED (14): the tag is the route that was on top, and the detail word is the surviving destination route.
- DISMISSED (15): the tag is the dismissed sheet. It is listed in `EVENTS`, so it carries no detail word.
- GESTURED (9) and RESIZED (11) read their signed words through `Gesture.decoded` and `Scene.sized`. A missing word reads as `Stopped`.
- LIFECYCLE (12) reads its phase code through `Scene.phase`.
- REFRESHED (16) carries its tag only and is listed in `EVENTS`. It names the scroll or list whose refresh control the user pulled.
- INSETS (17) reads four signed words through `Scene.insets`, in the order top, left, bottom and right. Fewer than four words read as `Stopped`.

Dispatch is three constant tables:
- `EVENTS` maps a kind to its tag-and-text decoder.
- `DETAILED` maps a kind to its tag-and-detail decoder.
- `MEASURED` maps a kind to its tag, detail and signed-word decoder. INSETS (17) is listed there.

## Invariants

- Pure: the module declares no foreign function and performs no fetch. The host fetches text, detail and words, and passes them in.
- Words the host never writes read as `Stopped`. A measured or detailed kind whose detail or words do not decode also reads as `Stopped`.
- `event` never fails. An unknown kind ends the loop the same way `Stopped` does.
- `carriesDetail` is true only for kinds in `DETAILED` and `MEASURED`. `carriesWords` is true only for kinds in `MEASURED`. `carriesText` is true only for kind 3.
- A tap names only its tag. A toggle names its tag and new state. Only `Changed` carries text, and that text is never packed into the 64-bit value.
- `signed` reads a word with its top bit set as negative.

## Negative Logic

- No I/O and no platform call. The foreign boundary is in [[Std Mobile Host]].
- No view tree or reconciliation. Those are in [[Std Mobile View]].
- No fetch of text, detail or words. The predicates say which fetches a value needs; the host performs them.
- No detail is read for a kind outside `DETAILED` and `MEASURED`.

## Dependencies and consumers

Depends on [[Std Mobile View]] for the `Event` type and its constructors, on [[Std Mobile Gesture]] for `Gesture.decoded` (kind 9), on [[Std Mobile Scene]] for `Scene.sized` (kind 11), `Scene.phase` (kind 12) and `Scene.insets` (kind 17). Consumers: [[Std Mobile Host]], whose `wait` calls the three predicates and the decoders in order. [[Std Mobile View]] exports no decoder; the decoders live in this module.

## Resolved Grill Log

- **Q:** Why a module apart from View? **A:** View holds the tree and its reconciliation; decoding the host's words is a separate boundary used only by Std.Mobile.Host, and keeping it apart keeps both modules under the size limit.
- **Q:** Why does a pop carry both routes? **A:** The platform may pop several routes in one back action; the reducer needs the previous top and the destination to refuse a stale report.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Host]] · [[Std Mobile Navigation]] · [[pudu_ios_navigation.h]] · [[pudu_ios_refresh.h]]
