---
type: module
path: "@root/cbits/pudu_ios_controls_test.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Controls Test]
---

# iOS Host Controls Test

## Purpose and interface

Private self-test of the value controls, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It runs when the environment variable `PUDU_UI_CONTROLS_TEST` is set, and drives each value control once through the path a person's input takes, then asks the program to stop.

## Behavior

The header holds one drive function per value kind: slider, stepper, segments, wheel, date, pages, well, text area and search. It has no kind dispatch. The kind table names each kind's `drive`, and the host's `selfTest` calls every shown node's `drive` when `PUDU_UI_CONTROLS_TEST` is set, before the run stops. The test drives the following, in order:
- Slider: the thumb to `low` plus 2.6 steps. The host reports it as `low` plus 3 steps, since the thumb rounds to the nearest step.
- Stepper: one step up.
- Segments: segment 1.
- Wheel: row 2.
- Date: 1,000,000,000 seconds since the epoch.
- Pages: page 2.
- Color well: opaque orange, (255, 128, 0, 255).
- Text area: "Notes".
- Search: "pudu".

Each step goes through the same queue and decoding a real touch uses, so the program receives the events it would receive from a person. After the last step the test queues a stop event.

## Invariants

- Each control is driven once, in the order above, so the program's labels read the same values from run to run.
- The test changes values only through the control's own input path, never by writing the platform property directly.

## Negative Logic

- No real touch input. The test reproduces the path of a touch on the same controls.
- No assertion inside the header. The program's labels show the values it received, and the simulator run reads them.
- No test of refusals. Stream defects are checked by the fixture [[Uses Mobile Controls]].

## Dependencies and consumers

Depends on [[iOS Host Values]], [[iOS Host Text]] and [[iOS Host Controls]] for the controls it drives, and on [[iOS Host Events]] for the stop event. Included by [[iOS Host Adapter]], which runs it from the self-test branch. Run by [[Native Controls Example]] in the simulator, as described in [[iOS Simulator Run]].

## Resolved Grill Log

- None beyond the logs of [[iOS Host Values]] and [[Std Mobile Control]].

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Native Controls Example]] · [[Native iOS Controls Delivery]]
