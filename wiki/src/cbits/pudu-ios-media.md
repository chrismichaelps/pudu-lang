---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_media.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, media]
aliases: [pudu-ios-media, iOS Host Media]
---

# pudu-ios-media

## Purpose and interface

In-app browser, speech and image picking of the iOS host (#989). Included once by [[iOS Host Adapter]], after the permission header. It implements the handlers of instructions BROWSE (66), SPEAK (67), HUSH (68) and PICK_IMAGE (73) of [[Std Mobile Stream]]. Its reports are BROWSED (37), SPOKE (38) and IMAGE_PICKED (41) of [[Std Mobile Events]], queued through [[iOS Host Events]]. The frameworks are always linked: SafariServices, AVFoundation and PhotosUI.

## Behavior

- BROWSE presents an in-app Safari view controller for the URL. BROWSED is queued from its finish delegate when the person closes it.
- SPEAK starts an AVSpeechSynthesizer utterance. The rate maps the percent onto the platform's default rate and is clamped to the platform's bounds. SPOKE is queued with `1` when the utterance finishes and `0` when it is cancelled.
- HUSH stops the synthesizer. The interrupted utterance answers SPOKE with `0`.
- PICK_IMAGE presents a PHPicker view controller limited to one image. The file representation is copied into the temporary directory, and IMAGE_PICKED carries the copy's path. A cancelled picker answers with `0` and empty text.
- All presentations happen on the main queue, and all answers are queued in stream order.

## Invariants

- Each BROWSE, SPEAK and PICK_IMAGE queues exactly one answer under its tag.
- A copy of a picked image is always written inside the temporary directory, never beside the app's data.

## Negative Logic

- No image bytes on the stream. The host writes a copy and reports its path.
- No retained browser after close. The view controller is released when it closes.
- No speech queue controls beyond HUSH. Pausing is not offered.

## Dependencies and consumers

Depends on SafariServices, AVFoundation (AVSpeechSynthesizer), PhotosUI (PHPickerViewController), UIKit presentation, [[iOS Host Events]] for the queue, and [[pudu-ios-kinds]] for the instruction table. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile Media]], [[Std Mobile Stream]] and [[Std Mobile Events]].

## Resolved Grill Log

- **Q:** Why is the picked image copied rather than read into the stream? **A:** The stream carries words and short text. An image is megabytes, so the host writes a file and reports its path.
- **Q:** Why does SPOKE carry a flag for an interrupted utterance? **A:** The program that started speech must be released either way. The flag tells it whether the phrase was finished.
- **Q:** Why is the copy kept in the temporary directory? **A:** The platform may clear that directory. The program reads the copy promptly, so the host need not manage its lifetime.
- **Q:** Why is the rate clamped by the host? **A:** The platform bounds differ from the percent scale. The host maps the request onto them, so the program never sends a value the platform refuses.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Media]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[PuduMedia]] · [[Uses Mobile Services]] · [[Toolbox Example]] · [[NATIVE-MOBILE]]
