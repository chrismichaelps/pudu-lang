---
type: module
path: "@root/lib/Std/Mobile/Scene.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile Scene]
---

# Std Mobile Scene

## Purpose and interface

Pure description of the scene the application runs in: its size in points, its size class along each axis, and its lifecycle phase. The host reports these as RESIZED and LIFECYCLE events, and [[Std Mobile View]] decodes them. The module decodes the words and codes of those events into typed values. It performs no I/O.

Exports:
- `type SizeClass = Compact | Regular`: a size class along one axis. Codes 1 and 2 in that order.
- `type Size = { width: Int32, height: Int32, horizontal: SizeClass, vertical: SizeClass }`: the scene's size in points and its size class along each axis.
- `type Phase = Active | Inactive | Background | Foreground`: where the application is in its lifecycle. Codes 1 to 4 in that order.
- `sized(words: &Array[Int32]) -> Option[Size]`: the size that the words `[width, height, horizontal, vertical]` describe.
- `phase(detail: UInt32) -> Option[Phase]`: the lifecycle phase that a detail word names.

## Invariants

- `sized` reads four words in the order width, height, horizontal class, vertical class. Fewer than four words, or a class code outside 1 and 2, decodes to `None`.
- `phase` reads the detail word of a LIFECYCLE event. A code outside 1 to 4 decodes to `None`.
- The constant tables `CLASSES` and `PHASES` hold the codes; no code is chosen by an if-ladder.

## Negative Logic

- No device model. The module names no device, no model table and no display size class other than the two the platform reports.
- No layout decision. Layout reads the `Size` and chooses its own arrangement.
- No event is created here. The host queues RESIZED and LIFECYCLE from [[iOS Host Scene]].

## Dependencies and consumers

Depends on no other Std Mobile module. Consumers: [[Std Mobile View]], which carries `Size` in `Resized` and `Phase` in `Lifecycle`; the host [[iOS Host Scene]]; the example [[Native Showcase Example]]; and the fixture [[Uses Mobile Capabilities]].

## Resolved Grill Log

- **Q:** Why report size classes instead of device models? **A:** New devices then need no release; layout follows the scene. A program that reads a size class runs on a device that did not exist when it was written.
- **Q:** Why report a size only when it changes? **A:** A layout pass repeats for reasons that do not change the scene. Reporting only changes keeps the program's events to real transitions. _Rejected:_ one report per layout pass.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[iOS Host Scene]] · [[Native iOS Capabilities Delivery]]
