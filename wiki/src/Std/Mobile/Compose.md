---
type: module
path: "@root/lib/Std/Mobile/Compose.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, compose]
aliases: [Std Mobile Compose]
---

# Std Mobile Compose

## Purpose and interface

Pure description of the system sheets for calendar events, mail and messages (#994). The module builds the ADD_EVENT, COMPOSE_MAIL and COMPOSE_MESSAGE instructions through [[Std Mobile Request]] and performs no I/O. Each sheet answers once with `Completed` (COMPLETED 47), decoded by [[Std Mobile Events]] and exposed by [[Std Mobile View]]. Sharing a file and the review prompt are in [[Std Mobile System]].

Exports:
- `addEvent(tag: UInt32, title: Str, start: Int64, end: Int64, location: Str) -> Bytes`: shows the platform event editor with a new event prefilled. `start` and `end` are Unix seconds.
- `mail(tag: UInt32, to: Array[Str], subject: Str, body: Str) -> Bytes`: shows the platform mail composer. The recipients are joined with commas.
- `message(tag: UInt32, to: Array[Str], body: Str) -> Bytes`: shows the platform message composer. The recipients are joined with commas.

## Behavior

- Each commit answers once under its tag: `Completed(tag, true)` when the person finished the sheet (saved the event, sent the mail or message), or `Completed(tag, false)` when they cancelled.
- A sheet the device cannot show answers `Completed(tag, false)`, at once or when the host learns that it cannot open.
- Times are split before writing into two signed words, the high word then the low word of the Unix seconds. The host joins them into its own date type.
- An empty recipient list writes an empty recipient field.

## Invariants

- Each commit carries its tag as its first word, so each answer matches its request.
- Text fields use the length-prefixed UTF-8 field of [[Std Mobile Request]].
- Times are exact and signed, so a time before 1970 needs no special case in either host.
- The module imports only [[Std Mobile Request]].

## Negative Logic

- No calendar permission. The event editor is presented by the platform, and the person saves through it.
- No sending on the person's behalf. Mail and messages open a composer that the person sends.
- No attachments. The sheets carry text only; files are shared through [[Std Mobile System]].
- No reading of the calendar, the mailbox or the message store.
- No platform call. Effects are made by [[pudu-ios-compose]] and [[PuduCompose]].

## Dependencies and consumers

Depends on [[Std Mobile Request]] for the ADD_EVENT, COMPOSE_MAIL and COMPOSE_MESSAGE instructions, and on [[Std Mobile Events]] for COMPLETED. Consumers: [[Std Mobile View]]; the iOS host [[pudu-ios-compose]]; the Android host [[PuduCompose]]; the fixture [[Uses Mobile Compose]]; and the example [[Outbox Example]].

## Resolved Grill Log

- **Q:** Why are times sent as Unix seconds in two words? **A:** Two signed words are exact and need no platform type in the stream. Each host converts them to its own date type, so one stream serves both hosts.
- **Q:** Why does one COMPLETED event cover the event editor, mail and messages? **A:** The program matches the answer by tag, so a new sheet needs no new event kind. Every finishable sheet has the same answer shape.
- **Q:** Why does Android report 1 once some sheets open? **A:** Android cannot see the outcome of an intent it hands to another application. Sharing reports the same way. A program that needs certainty must not rely on it on this host.
- **Q:** Why does a device that cannot show a composer answer at once? **A:** The composer cannot appear, so no later answer would come. Reporting 0 at once lets the program show the outcome.

## Referenced by

[[src/_MOC]] · [[Std Mobile View]] · [[Std Mobile Request]] · [[Std Mobile Events]] · [[Std Mobile System]] · [[pudu-ios-compose]] · [[PuduCompose]] · [[Uses Mobile Compose]] · [[Outbox Example]] · [[NATIVE-MOBILE]]
