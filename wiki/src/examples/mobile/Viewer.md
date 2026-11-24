---
type: module
path: "@root/examples/mobile/Viewer.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, web, media]
aliases: [Viewer Example]
---

# Viewer Example

## Purpose and interface

A program that exercises the web, video, audio, keyboard and back requests (#990) in one screen. The screen shows a web page at `about:blank` above a looping video. On start it plays a short sound and stops it, dismisses the keyboard, and turns back handling on so that the back gesture reports BACKED to the program.

The labels, in order:
- `Loaded: <bool or pending>`: `pending` until LOADED arrives for the page, then `true` or `false` by its detail.
- `Backs: <n>`: the number of BACKED reports the program has received.

The program uses [[Std Mobile Control]] for the page and the video, [[Std Mobile Media]] for the sound, [[Std Mobile System]] for the keyboard and the back setting, [[Std Mobile View]] for the tree and events, and [[Std Mobile Host]] for the apply and wait calls.

## Simulator expectations

The iOS suite runs the program with `PUDU_UI_WEB_TEST` set. The label must read `Loaded: true`, and the self-test must print `PUDU_WEB loaded yes`. The suite also expects a refusal: a LOAD sent to a label node is refused with the stream defect `loaded a page into a node that is not a web view:`.

## Invariants

- Each label is computed from the model, which changes only by events and by the program's own requests.
- The program never decides an answer itself. The label shows what the host reports.
- `Loaded` stays `pending` until its answer arrives, so the screen never shows a result the host did not send.

## Negative Logic

- No retry. A `false` answer is shown, and the page is not loaded again.
- No script channel between the page and the program.
- No stored state. The labels are rebuilt from events each run.

## Dependencies and consumers

Depends on [[Std Mobile Control]], [[Std Mobile Media]], [[Std Mobile System]], [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Host]] and [[Std Mobile Lifecycle]]. Hosts: [[iOS Host Adapter]] with [[pudu-ios-web]], and the Android host with [[PuduWeb]]. Its fixture-level counterpart is [[Uses Mobile Web]].

## Resolved Grill Log

- **Q:** Why is the page `about:blank` rather than a remote address? **A:** The run must not depend on the network. A page that loads without a connection makes LOADED a fact about the host, not about the network.
- **Q:** Why is `Loaded` shown as `pending` before the answer? **A:** A label reading `false` before the answer would present a failure the host never reported.
- **Q:** Why is back a counter and not a handled action? **A:** With back set to 1 the platform's own action is off, so the program receives each back as BACKED. The count shows that the answer reached the program.

## Referenced by

[[src/examples/_MOC]] · [[Std Mobile Control]] · [[Std Mobile Media]] · [[Std Mobile System]] · [[Std Mobile Events]] · [[pudu-ios-web]] · [[PuduWeb]] · [[Uses Mobile Web]] · [[NATIVE-MOBILE]]
