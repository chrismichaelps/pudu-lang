---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_notify.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, notification]
aliases: [pudu-ios-notify, iOS Host Notify]
---

# pudu-ios-notify

## Purpose and interface

Local notifications of the iOS host (#989). Included once by [[iOS Host Adapter]] in the host translation unit, after the permission header. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It implements the handlers of instructions NOTIFY (63) and UNNOTIFY (64) of [[Std Mobile Stream]]. Its report is NOTIFIED (35) of [[Std Mobile Events]], queued through [[iOS Host Events]].

## Behavior

- The real code is compiled only under `PUDU_PERMISSION_NOTIFICATIONS`. Otherwise the handlers are stubs that accept the instruction and schedule nothing.
- NOTIFY schedules a request with the platform notification center under the identifier `pudu.<id>`, with the title and body text. A delay of 0 or less is delivered at once. The same identifier replaces a pending request.
- UNNOTIFY removes the pending and delivered requests with that identifier.
- A delegate is set at launch. While the app is in front, the delegate lets banners show. A tap queues NOTIFIED with the id, including a tap that launched the app.

## Invariants

- The identifier is always the prefix `pudu.` followed by the program's id, so the host can tell its own requests from others.
- A tap is queued once per tap, in stream order with other events.

## Negative Logic

- No prompt. The permission request is made by the permission module.
- No delivery event. Only a tap is reported.
- No rescheduling after a reboot. The platform owns the request once it is scheduled.

## Dependencies and consumers

Depends on UserNotifications (the notification center and its delegate), Foundation, [[iOS Host Events]] for the queue, and [[pudu-ios-kinds]] for the instruction table. The framework is linked only when the notifications permission kind is declared. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile Notify]].

## Resolved Grill Log

- **Q:** Why is the identifier prefixed? **A:** The platform notification center is shared with the whole app. The prefix keeps the host's requests separate from any the app schedules itself.
- **Q:** Why is a tap that launched the app queued? **A:** A program that starts from a notification must learn which one it was. Dropping that tap would lose the only signal of the launch.
- **Q:** Why are the stubs silent rather than refusing? **A:** A program built without the permission still runs. A refused instruction would end the program for a feature the person did not grant.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Notify]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[PuduNotify]] · [[Toolbox Example]] · [[NATIVE-MOBILE]]
