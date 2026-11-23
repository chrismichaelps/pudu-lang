---
type: module
path: "@root/cbits/pudu_ios_scene.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Scene]
---

# iOS Host Scene

## Purpose and interface

Private scene implementation of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the root view controller of the application, the report of the scene's size and size classes, the report of its safe-area insets, and the observation of lifecycle transitions. It applies the status bar instruction STATUS (50) of [[pudu-ios-system]]; it reports the events RESIZED (11), LIFECYCLE (12) and INSETS (17) of [[Std Mobile View]].

## Behavior

- The application's root controller is `PuduRootController`. After each layout pass it reads its view's size in points and the horizontal and vertical size class of its trait collection.
- RESIZED carries four words: width, height, horizontal class, vertical class. The class codes are 1 compact and 2 regular, the codes of [[Std Mobile Scene]].
- RESIZED is queued only when the size or a class changed since the last report, and only once the view has a positive width.
- INSETS carries four words, the top, left, bottom and right safe-area insets, rounded to whole points. The root controller reports them once its view is laid out and whenever they change, as RESIZED does.
- LIFECYCLE is observed for four application notifications: became active (1), will resign active (2, inactive), entered background (3) and will enter foreground (4). Each queues a LIFECYCLE event with its code as the detail word, in the order the platform posts them.
- STATUS (50) sets the status bar style and hidden state of the root controller. The root controller does not defer the style to a child, so the scene keeps one setting. The handler is in [[pudu-ios-system]].

## Invariants

- The reported size is the size of the root view's bounds, rounded to whole points.
- A RESIZED event is never queued with a zero or negative width.
- Each lifecycle notification queues exactly one event.
- An INSETS event is never queued before the root view has been laid out.

## Negative Logic

- No stream write. The header writes no stream; the status bar handler lives in [[pudu-ios-system]].
- No device model. The report carries the size and classes only.
- No refusal. The scene is reported, never checked against what the program expects; a program that does not read these events ignores them.

## Dependencies and consumers

Depends on UIKit for the root controller, the trait collection and the notification centre, and on [[iOS Host Events]] for the queue. Included by [[iOS Host Adapter]]. Its values are decoded by [[Std Mobile Scene]] through [[Std Mobile View]], and its self-test is run by [[iOS Host Capability Test]].

## Resolved Grill Log

- **Q:** Why report lifecycle as events rather than as state? **A:** Each transition is a one-shot change the program reacts to in order. A stored state would need the program to compare it with the last value it saw.
- **Q:** Why report a size only when it changes? **A:** A layout pass repeats for reasons that leave the scene unchanged, and the program lays out again on every event. See [[Std Mobile Scene]].

## Services (#989)

The static `pudu_orientation_mask` holds the mask that the orientation request sets. It starts as all orientations. `supportedInterfaceOrientations` returns it, so the platform honors the lock. The codes are 0 all, 1 portrait and 2 landscape, mapped by [[pudu-ios-device]].

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Scene]] · [[Native iOS Capabilities Delivery]] · [[Native iOS Refresh Delivery]]
