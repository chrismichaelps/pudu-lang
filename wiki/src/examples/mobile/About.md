---
type: module
path: "@root/examples/mobile/About.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, device, network]
aliases: [About Example]
---

# About Example

## Purpose and interface

A program that shows what the device reports about itself: its platform, system version, model, locale, time zone and text scale, and its network link. It asks for the facts when it starts and again when it returns to the foreground, watches reachability, and keeps the screen awake while it is in front. Labels report each answer, so a simulator or device run reads the same results the host reports.

The labels, in order:
- `Platform: ios|android`: the platform that answered.
- `Version: …`: the system version.
- `Model: …`: the hardware model.
- `Locale: …`: the preferred language tag.
- `Zone: …`: the time zone identifier.
- `Scale: N`: the preferred text scale in percent.
- `Online: true|false`: `true` when the link is not `Offline`.
- `Link: Wifi|Cellular|Wired|Offline`: the link kind of the last report.

The program uses [[Std Mobile Device]] for the requests, [[Std Mobile View]] for the tree and the events, and [[Std Mobile Host]] for the apply and wait calls. Until the first `Described` answer arrives, the labels show `…`.

## Simulator expectations

The iOS simulator run starts the application with `PUDU_UI_DEVICE_TEST=1` and expects the labels `Platform: ios`, `Scale: 100` and `Online: true`, and the layout line `PUDU_DEVICE awake yes`. A second run sends `set network watching to 2` through a refused application, which the host reports as a stream defect.

## Invariants

- Each label is computed from the model, which is updated only by `Described` and `Networked` answers.
- The keep-awake setting is on while the program is in front and is turned off when it leaves the foreground.
- The program never decides a platform answer; it shows what the host returns.

## Negative Logic

- No timer and no polling. Facts are asked on start and on return to the foreground; the link is reported by the host on change.
- No address, network name or location is read or shown.
- No retry of a failed request. A `Stopped` answer leaves the label at its last value.

## Dependencies and consumers

Depends on [[Std Mobile Device]], [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Host]] and [[Std Mobile Lifecycle]]. Hosts: [[iOS Host Adapter]] with [[pudu-ios-device]], and the Android host with [[PuduDevice]]. Its fixture-level counterpart is [[Uses Mobile Device]].

## Resolved Grill Log

- **Q:** Why ask for the facts again on each return to the foreground rather than once at launch? **A:** The language, time zone and text scale change while the app runs. The label should match the device at the moment the person looks at it.
- **Q:** Why does the label show a link kind and also a boolean? **A:** The boolean is what most screens need; the kind is what a program deferring large transfers needs. The example shows both so a run reads the whole answer.
- **Q:** Why does the program turn keep-awake off itself when it leaves the foreground? **A:** The platform already clears the setting then. The program sets it again on return, so the label and the setting agree without a timer.

## Referenced by

[[src/_MOC]] · [[Std Mobile Device]] · [[pudu-ios-device]] · [[PuduDevice]] · [[Uses Mobile Device]] · [[NATIVE-MOBILE]]
