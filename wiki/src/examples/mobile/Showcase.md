---
type: module
path: "@root/examples/mobile/Showcase.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native]
aliases: [Native Showcase Example]
---

# Native Showcase Example

## Purpose and interface

A program that exercises the capability headers on the iOS simulator in one screen. It mounts a column holding an accessible label that carries a gesture recognizer set, a size label, a lifecycle label, a context menu on a picked label, a chose label, a progress bar, an activity indicator, an Add button and an animated keyed list. At start it shows a welcome alert with Later (cancel) and Start (plain). Choosing Start plays a success haptic and sets the progress bar to half.

The example uses [[Std Mobile Gesture]], [[Std Mobile Scene]], [[Std Mobile Access]], [[Std Mobile Feedback]], [[Std Mobile View]] and [[Std Mobile Host]].

The self-test is [[iOS Host Capability Test]]. It runs with `PUDU_UI_CAPABILITY_TEST` set. It takes the welcome alert's second choice, fires the gestures on the labelled control, picks the menu's second item, posts a resign and a return to active, and taps Add twice.

Expected report lines, in order, for an iPhone in portrait:

| Line | Source |
| --- | --- |
| `PUDU_ALERT Welcome` | host, the alert's title |
| `Gestures: press began, pan changed 12 -7, pinch changed 1500, rotation changed 785, swipe right` | label, the recognized gestures |
| `Size: compact regular` | label, the scene's size classes |
| `Phases: active inactive active` | label, the lifecycle transitions |
| `Picked: Delete` | label, the menu's choice |
| `Chose: Start` | label, the alert's choice |
| `Row 1`, `Row 2` | labels, the keyed rows after two taps on Add |
| `PUDU_HAPTIC 5` | host, the success haptic |
| `PUDU_ACCESS header=yes hint=Shows recognized gestures value=swipe right` | host, the first control with a hint |
| `PUDU_MOTION animated` | host, one animated commit ran |

The haptic line is printed only when `PUDU_UI_SELFTEST` is also set. The run sets both variables.

## Invariants

- The labels are the labels of the screen in order, as the simulator run reads them.
- Each gesture value is the one the self-test fires; the label shows the value the program decoded.
- The Showcase writes its state only through events. The welcome alert's Start is the only choice that sets progress.

## Negative Logic

- No real touch input. The self-test drives the same queue and decoding that real input uses.
- No animation or motion value is set by the program; the animated list is marked, and the host decides how it moves.
- The simulator suite does not yet compare these lines. The run is manual until the suite records them.

## Dependencies and consumers

Depends on the Std Mobile modules listed above and on the host headers [[iOS Host Gesture]], [[iOS Host Feedback]], [[iOS Host Access]], [[iOS Host Scene]], [[iOS Host Motion]] and [[iOS Host Capability Test]], through [[iOS Host Adapter]]. Run as described in [[iOS Simulator Run]].

## Resolved Grill Log

- **Q:** Why one program for all capabilities rather than one example each? **A:** One screen takes the path a real application takes, so a run tests the stream, the decoding and the host together. Separate examples would each prove one header and never the order they meet in.
- **Q:** Why a self-test rather than real touches? **A:** Real input needs a person or a simulator input path. The self-test drives the same queue and decoding, so its report is repeatable from run to run.

## Referenced by

[[src/examples/README]] · [[iOS Simulator Run]] · [[Uses Mobile Capabilities]] · [[iOS Host Capability Test]] · [[Native iOS Capabilities Delivery]]
