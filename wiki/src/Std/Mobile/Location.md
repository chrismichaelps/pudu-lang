---
type: module
path: "@root/lib/Std/Mobile/Location.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, location]
aliases: [Std Mobile Location]
---

# Std Mobile Location

## Purpose and interface

Pure description of the position requests a program may make and the decoding of the position answers. A locate request is answered once; a track request starts a stream of positions until it is turned off. The module builds the instructions through [[Std Mobile Stream]] and performs no I/O. Answers arrive as `Located` events that [[Std Mobile View]] decodes, and their words are decoded by [[Std Mobile Events]].

Exports:
- `type Accuracy = Precise | Approximate | Coarse`: the requested accuracy. Codes 0, 1 and 2 come from a const table.
- `type Position = { latitude: Int, longitude: Int, accuracy: Int, altitude: Int }`: latitude and longitude in ten-millionths of a degree, horizontal accuracy in meters rounded up, altitude in meters. A program divides for display.
- `locate(tag: UInt32, accuracy: Accuracy) -> Bytes`: a request answered by one `Located(tag, ...)`.
- `track(on: Bool, accuracy: Accuracy, distance: Int) -> Bytes`: a request that starts or stops position reports under tag 0. A negative distance is written as 0.
- `position(found: UInt32, values: &Array[Int32]) -> Option[Option[Position]]`: the decoding of the detail and words of a `Located` event. The outer `None` means the words are not a shape any host writes.
- `accuracyCode(accuracy: Accuracy) -> UInt32`: the code of an accuracy, read from the const table.

## Behavior

- `locate` names the tag its answer reports. Each locate request produces exactly one answer.
- `track(true, ...)` makes the host send a `Located` report under tag 0 for each new position. A second `track` replaces the accuracy and distance of the stream already running.
- `track(false, ...)` ends the reports. No later report follows it.
- `position` reads a detail of 1 with exactly four words as a position. A detail of 0 with no words decodes to `None` for the position, meaning no position is available. Any other shape is a stream defect and decodes to `Stopped`.

## Invariants

- Every `locate` request carries a tag, and its answer carries the same tag.
- Accuracy codes come from a constant table. No code is chosen by an if-ladder.
- Coordinates are integers in ten-millionths of a degree. No floating value crosses the boundary.
- The module imports only [[Std Mobile Stream]].

## Negative Logic

- No prompt. A locate request never asks the person for permission; the permission module owns that decision and its reported states, see [[Std Mobile Permission]].
- No silence as an answer. A position that cannot be found is answered with `None`, so a program waiting on a tag does not wait forever.
- No cached position. The module never keeps a position; each answer arrives as an event.
- No compiler scan of location calls. The permission request is what makes the build include the location host code.
- No platform call. The effects are made by the hosts in [[pudu-ios-location]] and [[PuduLocation]].

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the LOCATE and TRACK instructions, and on the event decoders of [[Std Mobile Events]] for LOCATED. Consumers: [[Std Mobile View]], which carries the `Located(UInt32, Option[Location.Position])` case; the iOS host [[pudu-ios-location]]; the Android host [[PuduLocation]]; the fixture [[Uses Mobile Location]]; and the example [[Where Example]].

## Resolved Grill Log

- **Q:** Why integer ten-millionths of a degree rather than floating degrees? **A:** The value is exact and identical on every platform, and it fits a signed 32-bit word, since longitude reaches at most 1,800,000,000. The resolution is about one centimeter, finer than any phone fix. _Rejected:_ floating degrees, whose encoding differs between hosts.
- **Q:** Why must every locate request get an answer? **A:** A program that waits on a tag must always be released. No position is an answer, so the program can show that state instead of waiting.
- **Q:** Why does a locate request never prompt? **A:** Asking is the permission module's job and reports its own states. A prompt hidden inside a locate would split that decision across two places.
- **Q:** Why does all tracking share tag 0? **A:** One tracking stream exists per application. A second track request replaces its settings, so a tag per stream would add a choice with no use.
- **Q:** Why is the position a separate decoder rather than part of the view? **A:** The decoder is pure and can be checked by the stdlib fixture without a host. The view only holds the decoded value.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Std Mobile Permission]] · [[pudu-ios-location]] · [[PuduLocation]] · [[NATIVE-MOBILE]]
