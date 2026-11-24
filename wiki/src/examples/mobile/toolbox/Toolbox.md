---
type: module
path: "@root/examples/mobile/toolbox/Toolbox.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, notification, authentication, media, device, motion]
aliases: [Toolbox Example]
---

# Toolbox Example

## Purpose and interface

A program that exercises the device services batch (#989) in one screen. On start it asks for the notifications permission, schedules one local notification, reads the battery, asks the person to confirm device ownership, speaks a short phrase, locks the orientation to portrait, sets brightness to 50, and turns on motion sensing. Each answer updates one label, so a simulator or device run reads the same results the host reports.

The labels, in order:
- `Battery: <level or unknown>`: the battery level in percent from POWERED, or `unknown` when the host reports -1.
- `Authenticated: <bool>`: the answer of AUTHENTICATED.
- `Spoke: <bool>`: the answer of SPOKE for the phrase.
- `Motion: <none or x y z>`: `none` until a SENSED report arrives, then its three words.

The program uses [[Std Mobile Notify]], [[Std Mobile Auth]], [[Std Mobile Media]] and [[Std Mobile Device]] for the requests, [[Std Mobile View]] for the tree and the events, and [[Std Mobile Host]] for the apply and wait calls.

The notifications permission is declared in the `pudu.toml` beside the program, under `[app.permissions]`, with a reason. The build requires the declaration because the program uses the notification module.

## Simulator expectations

The iOS suite runs the program with `PUDU_UI_SERVICES_TEST` set. The simulator has no passcode, so the label reads `Authenticated: false`. The self-test prints `PUDU_SERVICES authenticated powered spoke` with yes or no for each. The suite also expects the refusals of a brightness of 101 and an orientation code of 3, reported by the host as stream defects.

## Invariants

- Each label is computed from the model, which is updated only by events and by the program's own requests.
- The program never decides an answer itself; each label shows what the host reports.
- Motion labels stay `none` on a simulator, where no accelerometer is available.

## Negative Logic

- No retry of a refused or `false` answer. The program shows the answer and does not ask again.
- No background behavior. The brightness and orientation settings are tied to the program's foreground session, and the platform restores its own when the app leaves.
- No stored state. The labels are rebuilt from events each run.

## Dependencies and consumers

Depends on [[Std Mobile Notify]], [[Std Mobile Auth]], [[Std Mobile Media]], [[Std Mobile Device]], [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Host]] and [[Std Mobile Lifecycle]]. Hosts: [[iOS Host Adapter]] with [[pudu-ios-notify]], [[pudu-ios-media]] and the device services, and the Android host with [[PuduNotify]], [[PuduAuth]], [[PuduMedia]] and [[PuduDevice]]. Its fixture-level counterpart is [[Uses Mobile Services]].

## Resolved Grill Log

- **Q:** Why does the example ask for authentication on a simulator that has no passcode? **A:** The run checks the false path as well as the true one. A simulator answer of `false` proves the program is released when no confirmation is possible.
- **Q:** Why are brightness and orientation set in one screen? **A:** The suite must read each standing setting's effect in the same run. One program shows all three results without a second launch.
- **Q:** Why is the motion label `none` until a report arrives? **A:** A simulator reports no accelerometer. Showing zeros would present a stationary device the platform never measured.

## Referenced by

[[src/examples/_MOC]] · [[Std Mobile Notify]] · [[Std Mobile Auth]] · [[Std Mobile Media]] · [[Std Mobile Device]] · [[pudu-ios-notify]] · [[PuduNotify]] · [[Uses Mobile Services]] · [[NATIVE-MOBILE]]
