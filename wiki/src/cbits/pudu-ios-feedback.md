---
type: module
path: "@root/cbits/pudu_ios_feedback.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Feedback]
---

# iOS Host Feedback

## Purpose and interface

Private feedback implementation of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the ALERT and HAPTIC instructions, the presentation of alerts one at a time, the haptic players, and the two indicators: a determinate progress bar and an activity indicator. The header handles the instructions ALERT (28), VALUE (29) and HAPTIC (30) of [[Std Mobile Stream]], and the kinds PROGRESS (10) and ACTIVITY (11).

## Behavior

- ALERT queues an alert with its tag, a style code, a title, a message, and its choices. Style 0 is an alert and style 1 an action sheet. Each choice carries a role code and a label; role 0 is the default action, 1 the cancel action and 2 the destructive action.
- The alert presents when no other alert is shown. Later alerts wait in order. A choice reports CHOSE with the alert's tag, and the choice's index in the detail word. The shown alert then clears, and the next one presents.
- An action sheet is anchored to the bottom centre of the presenting view, so it has a source on a large screen.
- HAPTIC plays a generator for its code: 1 selection, 2 light impact, 3 medium impact, 4 heavy impact, 5 success, 6 warning, 7 failure. The notification codes 5 to 7 use the platform's notification generator.
- When the environment variable `PUDU_UI_SELFTEST` is set, each played haptic also prints `PUDU_HAPTIC` with its code.
- VALUE sets a progress bar's completion from thousandths, clamped at 1000.
- STATE on an activity indicator starts or stops its spinner. The indicator stays visible when it stops.

## Invariants

- One alert is presented at a time, and each queued alert is presented exactly once.
- A choice's index is its position in the alert's choices, so the index in CHOSE always names a choice the program sent.
- A haptic code outside 1 to 7 has no player and is refused.

## Negative Logic

- No choice is repeated. A choice fires its event once; a second tap on the same alert finds it dismissed.
- No text is translated. Titles, messages and labels pass through as the program wrote them.
- Refusal: a style code above 1, or a role code of 3 or more, refuses the whole alert and nothing is queued. The host ends the process with a message naming the defect. A haptic code outside 1 to 7 ends the process the same way.
- No animation of the progress bar. The bar takes each value as it is set.

## Dependencies and consumers

Depends on UIKit for the alert controller, the feedback generators and the indicators, and on [[iOS Host Events]] for the CHOSE queue and the shown root. Included by [[iOS Host Adapter]]. Its instructions are encoded by [[Std Mobile Feedback]] and [[Std Mobile Stream]], and its self-test is run by [[iOS Host Capability Test]].

## Resolved Grill Log

- **Q:** Why commands rather than views for alerts and haptics? **A:** They are one-shot effects with a reported outcome, not persistent state. See [[Std Mobile Feedback]].
- **Q:** Why one alert at a time? **A:** The platform presents one modal presentation at a time. Queueing keeps the program's order and keeps every choice reachable, where a second presentation would cover or drop the first.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Feedback]] · [[Native iOS Capabilities Delivery]]
