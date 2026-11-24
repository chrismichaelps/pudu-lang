---
type: module
path: "@root/lib/Std/Mobile/Pick.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, pick]
aliases: [Std Mobile Pick]
---

# Std Mobile Pick

## Purpose and interface

Pure description of the contact, document and photo pickers and of audio recording (#991). The module builds the PICK_CONTACT, PICK_DOCUMENT, TAKE_PHOTO and RECORD instructions through [[Std Mobile Request]] and performs no I/O. Answers arrive as `ContactPicked` and `Filed` events that [[Std Mobile View]] decodes, using the decoders of [[Std Mobile Events]].

Types:
- `type Contact = { name: Str, phones: Array[Str], emails: Array[Str] }`

Exports:
- `pickContact(tag: UInt32) -> Bytes`: shows the platform contact picker. `CONTACT_PICKED` answers with the chosen contact, or with a cancellation. No contacts permission is needed.
- `pickDocument(tag: UInt32, types: Array[Str]) -> Bytes`: shows the platform document picker. The MIME types are joined with commas; an empty list accepts any file. `FILED` answers with the path of a copy in the temporary directory.
- `takePhoto(tag: UInt32) -> Bytes`: opens the platform camera. `FILED` answers with the path of a JPEG in the temporary directory, or with a cancellation.
- `record(tag: UInt32, on: Bool) -> Bytes`: starts recording audio when `on` is true and stops it when false. Stopping answers `FILED` with the path of the recording.
- `contact(text: Str) -> Option[Contact]`: decodes the text of a `CONTACT_PICKED` answer. The text has exactly three lines: the name, the phone numbers joined by ",", and the email addresses joined by ",". Empty lines give empty lists. Any other line count yields `None`.

## Behavior

- `pickDocument`, `takePhoto` and `pickContact` each answer once under their tag, with a value or a cancellation.
- A recording answers once, when the program stops it. A recording that the host cannot start answers `FILED` with detail 0.
- Each picked or captured file is copied into the temporary directory before it is reported, so the program reads it from a path the application owns.

## Invariants

- Each request carries its tag as its first word, so every answer can be matched to its request.
- Text fields use the length-prefixed UTF-8 field of [[Std Mobile Request]].
- The module imports only [[Std Mobile Request]] and [[Std Mobile Events]] for decoding.

## Negative Logic

- No contact list access. The contact picker returns the single contact the person chose, so the program never reads the address book.
- No file bytes. Files cross the stream as paths; the program reads them with the file library.
- No camera or microphone check here. Permission is requested by the program through [[Std Mobile Permission]] before it calls `takePhoto` or `record`.
- No platform call. Effects are made by [[pudu-ios-pick]] and [[PuduPick]].

## Dependencies and consumers

Depends on [[Std Mobile Request]] for the PICK_CONTACT, PICK_DOCUMENT, TAKE_PHOTO and RECORD instructions, and on [[Std Mobile Events]] for CONTACT_PICKED and FILED. Consumers: [[Std Mobile View]]; the iOS host [[pudu-ios-pick]]; the Android host [[PuduPick]]; the fixture [[Uses Mobile Pick]]; and the example [[Picker Example]].

## Resolved Grill Log

- **Q:** Why does one FILED event cover documents, photos and recordings? **A:** All three answer with a file the program reads with the file library. The tag says which request the file answers, so a second event type would repeat the same shape.
- **Q:** Why is the contact picker used rather than contacts access? **A:** The person shares one contact deliberately, so the request needs no permission prompt and the program never sees the rest of the address book.
- **Q:** Why are picked files copied into the temporary directory? **A:** The platform's grant to a picked file can lapse. The copy lives with the application, and the platform may clear it, so the program reads it promptly.

## Referenced by

[[src/_MOC]] · [[Std Mobile View]] · [[Std Mobile Request]] · [[Std Mobile Events]] · [[pudu-ios-pick]] · [[PuduPick]] · [[Uses Mobile Pick]] · [[Picker Example]] · [[NATIVE-MOBILE]]
