---
type: module
path: "@root/lib/Std/Mobile/Media.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, media]
aliases: [Std Mobile Media]
---

# Std Mobile Media

## Purpose and interface

Pure description of the in-app browser, speech and image picking requests (#989). The module builds the BROWSE, SPEAK, HUSH and PICK_IMAGE instructions through [[Std Mobile Request]] and performs no I/O. Answers arrive as `Browsed`, `Spoke` and `ImagePicked` events that [[Std Mobile View]] decodes, using the decoders of [[Std Mobile Events]].

Exports:
- `browse(tag: UInt32, url: Str) -> Bytes`: shows the page in an in-app browser. `BROWSED` answers when it closes.
- `speak(tag: UInt32, text: Str, language: Str, rate: Int) -> Bytes`: speaks the text. The rate is a percent where 100 is normal. An empty language tag selects the device's language. `SPOKE` answers when speech ends.
- `hush() -> Bytes`: stops speech. The utterance that was interrupted answers `SPOKE` with `false`.
- `pickImage(tag: UInt32) -> Bytes`: shows the platform photo picker. `IMAGE_PICKED` answers.

## Behavior

- Each `browse`, `speak` and `pickImage` request answers once under its tag.
- `speak` with a tag that has an earlier utterance still pending does not cancel that utterance. Only `hush` stops speech.
- The picked image arrives as the path of a copy in the app's temporary directory, or as a cancellation with empty text. The bytes of the image never cross the stream.

## Invariants

- Each request carries its tag as its first word, so every answer can be matched to its request.
- Text fields use the length-prefixed UTF-8 field of [[Std Mobile Request]].
- The module imports only [[Std Mobile Request]].

## Negative Logic

- No image data. A picked image is a file path; the stream carries words and short text only.
- No rate check here. The host clamps the rate to the platform's bounds, so a program may pass any integer.
- No playback control beyond `hush`. Pausing and resuming speech are not part of the interface.
- No platform call. Effects are made by [[pudu-ios-media]] and [[PuduMedia]].

## Dependencies and consumers

Depends on [[Std Mobile Request]] for the BROWSE, SPEAK, HUSH and PICK_IMAGE instructions, and on [[Std Mobile Events]] for BROWSED, SPOKE and IMAGE_PICKED. Consumers: [[Std Mobile View]]; the iOS host [[pudu-ios-media]]; the Android host [[PuduMedia]]; the fixture [[Uses Mobile Services]]; and the example [[Toolbox Example]].

## Resolved Grill Log

- **Q:** Why is the picked image a copied file path rather than bytes? **A:** Images are megabytes, and the stream carries words and short text. The copy lives in the temporary directory, which the platform may clear, so the program reads it promptly.
- **Q:** Why does each request get exactly one answer? **A:** A program waiting on a tag must never wait forever. A browser that is dismissed, a speech that is interrupted, and a cancelled picker each answer.
- **Q:** Why does the rate take a percent rather than a platform value? **A:** Platforms use different rate scales. A percent with 100 as normal is the same request on both, and the host maps it onto its own scale.
- **Q:** Why is `hush` a separate instruction? **A:** Stopping speech has no tag of its own. Its effect is reported through the interrupted utterance's `SPOKE`, so no extra answer type is needed. _Rejected:_ a cancel tag for each utterance, which adds a choice with no use.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Request]] · [[Std Mobile Events]] · [[pudu-ios-media]] · [[PuduMedia]] · [[Uses Mobile Services]] · [[Toolbox Example]] · [[NATIVE-MOBILE]]
