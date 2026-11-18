---
type: module
path: "@root/cbits/pudu_ios_capability_test.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Capability Test]
---

# iOS Host Capability Test

## Purpose and interface

Private self-test of the capability headers of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It runs when the environment variable `PUDU_UI_CAPABILITY_TEST` is set, acts as a person and the system would, and reports what the program made of it. It is used by the Showcase run of [[Native Showcase Example]].

## Behavior

The test runs in one fixed order, through the same paths real input takes:

1. It takes the shown alert's second choice, and prints `PUDU_ALERT` with the alert's title.
2. For each control that carries recognizers, it fires press began, pan changed by 12 and -7 points, pinch changed to 1500, rotation changed to 785 thousandths of a radian, and a swipe to the right.
3. For each control, it picks the second item of its context menu, if it has one.
4. It posts a resign-active notification and then a became-active notification.
5. It taps the button titled Add twice.

It then queues a stop event through the done block the host passes in.

After the program returns, the host prints:
- `PUDU_ACCESS header=yes|no hint=... value=...` for the first control with an accessibility hint, with its header trait and its hint and value.
- `PUDU_MOTION animated` when an animated group ran at least once.

The haptic line `PUDU_HAPTIC` is printed by [[iOS Host Feedback]] only when `PUDU_UI_SELFTEST` is also set.

## Invariants

- The order of steps is fixed, so the report lines are compared as a sequence.
- Each gesture reaches the program through the same fire path a recognizer uses, so the event queue and the decoding of [[Std Mobile Gesture]] are exercised.

## Negative Logic

- No UIKit recognition is re-tested. The recognizers' own behavior is the platform's; the test checks what the program does with what they report.
- No physical input and no device rotation. Scene changes arrive as notifications, the same path the system uses.
- No refusal. The self-test has no stream and reports no defect; a failing step appears as a missing or changed report line.

## Dependencies and consumers

Depends on UIKit and the Objective-C runtime, and on the headers [[iOS Host Access]], [[iOS Host Feedback]], [[iOS Host Gesture]] and [[iOS Host Motion]] for the functions it calls. Included by [[iOS Host Adapter]]. Run by [[Native Showcase Example]] and by the simulator suite [[iOS Simulator Run]].

## Resolved Grill Log

- **Q:** Why post the notifications rather than rotate the device or background the app? **A:** The test runs headless in the simulator. The notifications are the same events the system posts, so the program sees the same sequence without a device action.
- **Q:** Why one fixed order of steps? **A:** The expected report is a sequence. A fixed order makes a changed line point at one step, where a random order would make every line depend on the others.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Native Showcase Example]] · [[Native iOS Capabilities Delivery]]
