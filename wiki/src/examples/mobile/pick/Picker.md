---
type: module
path: "@root/examples/mobile/pick/Picker.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, pick, media]
aliases: [Picker Example]
---

# Picker Example

## Purpose and interface

A program that exercises the pickers, recording, badge, secure screen and toast requests (#991) in one screen. Its package declares the camera and microphone in `pudu.toml`, so the platform asks for those permissions only when the program requests them.

The screen shows one button for each request and a label for each answer, in order:
- `Contact: <name or none>`: the name of the picked contact, `none` after a cancellation.
- `Document: <path or none>`: the path of the picked document.
- `Photo: <path or none>`: the path of the photo taken.
- `Recording: <path or none>`: the path of the recording, shown after RECORD on 0 answers.
- `Badge: <n>`: the count last sent to the badge.

The program uses [[Std Mobile Pick]] for the pickers and recording, [[Std Mobile System]] for the badge, the secure screen and the toast, [[Std Mobile View]] for the tree and events, and [[Std Mobile Host]] for the apply and wait calls.

## Simulator expectations

The iOS suite runs the program with no self-test interaction, and checks its labels at rest: each label reads its empty form, `none` or `0`. The suite also expects a refusal: RECORD sent with the word 2 is refused with the stream defect `set recording to`.

## Invariants

- Each label is computed from the model, which changes only by events and by the program's own requests.
- The program never decides an answer itself. The label shows what the host reports.
- Each file label shows a path in the temporary directory, never file contents.

## Negative Logic

- No contacts list. The program receives one contact per pick.
- No retry after a cancellation. A `none` answer is shown, and the picker is not reopened.
- No stored state. The labels are rebuilt from events each run.

## Dependencies and consumers

Depends on [[Std Mobile Pick]], [[Std Mobile System]], [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Host]] and [[Std Mobile Lifecycle]]. Hosts: [[iOS Host Adapter]] with [[pudu-ios-pick]], and the Android host with [[PuduPick]]. Its fixture-level counterpart is [[Uses Mobile Pick]].

## Resolved Grill Log

- **Q:** Why is the camera and microphone declared in `pudu.toml` rather than only requested at run time? **A:** The platform's permission text must name the capability before the program asks for it. Declaring it in the manifest makes the prompt appear at the request, not as a failure.
- **Q:** Why does the screen show `none` rather than hiding a label after a cancellation? **A:** A label that disappears looks like a lost answer. `none` shows that the host reported a cancellation.
- **Q:** Why is the badge a count label and not a second button? **A:** The badge is a single number the program sets, so one label shows the value last sent and needs no extra control.

## Referenced by

[[src/examples/_MOC]] · [[Std Mobile Pick]] · [[Std Mobile System]] · [[Std Mobile Events]] · [[pudu-ios-pick]] · [[PuduPick]] · [[Uses Mobile Pick]] · [[NATIVE-MOBILE]]
