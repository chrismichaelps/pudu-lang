---
type: module
path: "@root/examples/mobile/Services.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, system]
aliases: [Services Example]
---

# Services Example

## Purpose and interface

A program that exercises the system requests on a phone screen: it copies a text and pastes it back, opens a URL that no application handles, opens the share sheet, and sets the status bar to light text. Labels report each answer, so a simulator or device run reads the same results the host reports.

The labels, in order:
- `Pasted: from Pudu`: the text read back from the clipboard after the copy.
- `Opened: false`: the answer for `pudu-unhandled://nothing`, which no application handles.
- `Shared: false`: the answer for the share sheet. On iOS it is false when the sheet is dismissed without a target. On Android it is true once the chooser opens.

The program uses [[Std Mobile System]] for the requests, [[Std Mobile View]] for the tree and the events, and [[Std Mobile Host]] for the apply and wait calls. The status bar is set once when the screen is first built.

The example also has one refusal case the host must report: a status bar style code outside the table, sent as a defect, is refused with `unknown status bar style`.

## Simulator expectations

The iOS simulator run expects these labels: `Pasted: from Pudu`, `Opened: false`, `Shared: false`. The share sheet is shown and dismissed by the run, which is the self-test line `PUDU_SYSTEM share shown` of [[pudu-ios-system]]. The status bar is light text, `PUDU_SYSTEM status light shown`.

The refusal `unknown status bar style` is expected in the host log when the case is run.

## Invariants

- Each label is computed from the model, which is updated only by system reports.
- The program never reads the clipboard on its own; the paste is a request like the others.
- The program makes no decision about the platform answers; it shows them.

## Negative Logic

- No retry of the unhandled URL and no second share.
- No timer. The answers arrive when the platform gives them.
- No write to the clipboard after the one copy.

## Dependencies and consumers

Depends on [[Std Mobile System]], [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Host]] and [[Std Env]]. Hosts: [[iOS Host Adapter]] with [[pudu-ios-system]] and [[pudu-ios-scene]]; and the Android host with [[PuduSystem]]. Its fixture-level counterpart is [[Uses Mobile System]].

## Resolved Grill Log

- **Q:** Why paste what the program just copied? **A:** It proves both requests reach the platform and that the text returns intact, with one label to check.
- **Q:** Why an unhandled URL rather than a web address? **A:** A web address opens a browser and depends on the network. An unhandled scheme answers false on every device without any outside service.
- **Q:** Why is the share label false on the simulator run? **A:** The run dismisses the sheet without a target, so the iOS answer is the one the run can check. Android's answer is true once the chooser opens, and the Android run checks that label separately.

## Referenced by

[[src/examples/_MOC]] · [[Uses Mobile System]] · [[pudu-ios-system]] · [[PuduSystem]] · [[NATIVE-MOBILE]]
