---
type: module
path: "@root/lib/Std/Mobile/Request.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, request]
aliases: [Std Mobile Request]
---

# Std Mobile Request

## Purpose and interface

Instruction writers for the device requests that are not about the view (#989): notifications, device-owner authentication, the in-app browser, speech, the battery, screen brightness, orientation lock, motion sensing and the photo picker. Each writer appends its instruction to a stream and returns the extended stream, as the writers of [[Std Mobile Stream]] do. The module performs no I/O. Its answers arrive as events that [[Std Mobile Events]] decodes into cases of [[Std Mobile View]].

Exports, with their codes:
- `notify(out, id: UInt32, delay: UInt32, title: Str, body: Str)`: NOTIFY 63.
- `unnotify(out, id: UInt32)`: UNNOTIFY 64.
- `authenticate(out, reported: UInt32, reason: Str)`: AUTHENTICATE 65, answered by AUTHENTICATED under `reported`.
- `browse(out, reported: UInt32, url: Str)`: BROWSE 66, answered by BROWSED when the browser closes.
- `speak(out, reported: UInt32, rate: UInt32, language: Str, text: Str)`: SPEAK 67, answered by SPOKE.
- `hush(out)`: HUSH 68.
- `battery(out, reported: UInt32)`: BATTERY 69, answered by POWERED.
- `brightness(out, percent: UInt32)`: BRIGHTNESS 70.
- `orientation(out, code: UInt32)`: ORIENTATION 71, code 0 any, 1 portrait, 2 landscape.
- `sense(out, on: UInt32, interval: UInt32)`: SENSE 72, a flag of 1 to start or 0 to stop, and the interval in milliseconds.
- `pickImage(out, reported: UInt32)`: PICK_IMAGE 73, answered by IMAGE_PICKED.

## Behavior

- Each writer's words follow its code word. NOTIFY is the id, the delay in seconds, then the title and body text fields. SPEAK is the tag, the rate, the language text and the text. AUTHENTICATE and BROWSE carry a text field after their tag. HUSH carries no words.
- The tag a writer receives is the tag its answer reports. The program chooses it and matches the answer to its request by it.

## Web, video and audio (#990)

- AUDIO 76 (`audio`): tag, playing (0 or 1), looping (0 or 1), and source text. Playing 1 starts a sound under the tag, replacing any sound already under it. Playing 0 stops it. ENDED answers with the tag when a non-looping sound ends.
- KEYBOARD 77 (`keyboard`): no words. It dismisses the on-screen keyboard.
- BACK 78 (`back`): 1 makes the platform's back gesture or button answer BACKED, and 0 returns it to the platform. iOS has no system back gesture outside navigation and ignores the word.
- The instruction bound is now 79.

## Invariants

- Codes 63 to 73 are constants of this module. The instruction bound is 74.
- Text fields use the length-prefixed UTF-8 field and words use the word writer of [[Std Mobile Stream]]; those two helpers are the only names this module imports.
- No writer checks a range. Refusals of out-of-range values are the host's, see [[pudu-ios-nodes]] and [[pudu-ios-device]].

## Negative Logic

- No prompt. Permission is owned by [[Std Mobile Permission]].
- No answer is kept. The module never stores a result; each answer arrives as an event.
- No platform call. The effects are made by [[pudu-ios-notify]], [[pudu-ios-media]], [[pudu-ios-device]] and [[PuduNotify]], [[PuduAuth]], [[PuduMedia]], [[PuduDevice]].

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for `field` and `words`. Consumers: [[Std Mobile Notify]], [[Std Mobile Auth]] and [[Std Mobile Media]], which call the writers for their requests, and [[Std Mobile Device]], which calls the writers for battery, brightness, orientation and sense.

## Resolved Grill Log

- **Q:** Why a separate module rather than more writers in [[Std Mobile Stream]]? **A:** Stream holds the view stream and passed 500 lines. Requests that are not about the view share its code space and word helpers, but they live apart. _Rejected:_ raising the limit for Stream.
- **Q:** Why do these codes continue the view stream's numbering? **A:** The host dispatches every instruction from one table and one bound. A second numbering would need a second dispatch.
- **Q:** Why does every writer take the tag from the program? **A:** A program matches an answer to the request it sent. The host echoes the tag, so an answer can always be routed.

## Pickers and system touches (#991)

Writers for PICK_CONTACT 79, PICK_DOCUMENT 80, TAKE_PHOTO 81, RECORD 82, BADGE 83, SECURE 84 and TOAST 85. INSTRUCTIONS is 86. RECORD and SECURE words above 1 are refused as `set recording to` and `set secure screen to`. The writers for the pickers are in [[Std Mobile Pick]].

## System sheets (#994)

Writers for SHARE_FILE 86, REVIEW 87, ADD_EVENT 88, COMPOSE_MAIL 89 and COMPOSE_MESSAGE 90. INSTRUCTIONS is 91. REVIEW takes no words. The writers for the sheets are in [[Std Mobile Compose]] and [[Std Mobile System]].

## Referenced by
 · [[Viewer Example]] · [[pudu-ios-web]] · [[PuduWeb]]
[[src/Std/_MOC]] · [[Std Mobile Stream]] · [[Std Mobile Notify]] · [[Std Mobile Auth]] · [[Std Mobile Media]] · [[Std Mobile Device]] · [[Std Mobile Events]] · [[Uses Mobile Services]] · [[NATIVE-MOBILE]]
