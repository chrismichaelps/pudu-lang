---
type: module
path: "@root/lib/Std/Mobile/Notify.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, notification]
aliases: [Std Mobile Notify]
---

# Std Mobile Notify

## Purpose and interface

Pure description of local notification requests (#989). The module builds the NOTIFY and UNNOTIFY instructions through [[Std Mobile Request]] and performs no I/O. A tap on a notification arrives as a `Notified` event that [[Std Mobile View]] decodes, using the decoders of [[Std Mobile Events]].

Exports:
- `schedule(id: UInt32, after: Int, title: Str, body: Str) -> Bytes`: schedules a local notification `after` seconds from now. A negative delay is written as 0.
- `cancel(id: UInt32) -> Bytes`: cancels a pending or delivered notification with that id.

## Behavior

- A schedule with an id that is already pending replaces the earlier notification with that id.
- A cancel of an unknown or already delivered id has no effect on the program.
- The delay is a count of seconds, not a wall-clock time. A program that holds a calendar time computes the delay from [[Std Mobile Time]] before the call.
- The request that makes the notifications permission available is made by the program. The build fails when the program uses this module and the permission is not declared in `pudu.toml`.

## Invariants

- Each instruction carries the id as its first word, so a cancel names the same notification a schedule created.
- Text fields use the length-prefixed UTF-8 field of [[Std Mobile Request]].
- The module imports only [[Std Mobile Request]].

## Negative Logic

- No prompt. The module does not ask the person for permission; the request is owned by [[Std Mobile Permission]].
- No delivery report. A scheduled notification is not confirmed by an event; only a tap is reported.
- No recurrence. Each schedule is one notification.
- No platform call. The effects are made by [[pudu-ios-notify]] and [[PuduNotify]].

## Dependencies and consumers

Depends on [[Std Mobile Request]] for the NOTIFY and UNNOTIFY instructions. Consumers: [[Std Mobile View]], which carries the `Notified(UInt32)` case; the iOS host [[pudu-ios-notify]]; the Android host [[PuduNotify]]; the fixture [[Uses Mobile Services]]; and the example [[Toolbox Example]].

## Resolved Grill Log

- **Q:** Why is the delay a count of seconds rather than a wall-clock time? **A:** A delay has one meaning in every time zone. A program that starts from a calendar time converts it once, with the time library, and sends the delay.
- **Q:** Why does the same id replace an earlier notification? **A:** A program that reschedules a reminder should not have to track whether the old one still exists. Replacement keeps one notification per id.
- **Q:** Why is a negative delay written as 0? **A:** A negative delay has no meaning for a notification. Delivery now is the nearest valid reading, and it avoids a defect for a computed value that falls just before zero.
- **Q:** Why does a schedule never prompt? **A:** Asking is the permission module's job. A prompt inside a schedule would split the decision across two places. _Rejected:_ requesting permission on the first schedule, which hides the state from the program.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Request]] · [[Std Mobile Events]] · [[Std Mobile Permission]] · [[pudu-ios-notify]] · [[PuduNotify]] · [[Toolbox Example]] · [[NATIVE-MOBILE]]
