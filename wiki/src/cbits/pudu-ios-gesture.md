---
type: module
path: "@root/cbits/pudu_ios_gesture.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Gesture]
---

# iOS Host Gesture

## Purpose and interface

Private gesture implementation of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the GESTURES instruction, the attachment of UIKit recognizers to a control, and the GESTURED event each recognizer reports. The header handles one instruction of [[Std Mobile Stream]], GESTURES (27), and the event kind GESTURED (9) of [[Std Mobile View]].

## Behavior

- GESTURES names a node, the tag its events report, and a mask. The mask bits are 1 long press, 2 pan, 4 pinch, 8 rotation and 16 swipe, the bits of [[Std Mobile Gesture]].
- Attaching replaces the recognizers the control already carries. Each recognizer is created for its bit only; a bit that names no recognizer is ignored.
- A swipe carries one recognizer per direction, left, right, up and down, so a swipe in each direction is reported with its own code.
- Each recognizer reports one GESTURED event with the tag, the recognizer's bit as the detail word, and three signed words. A continuous gesture reports its phase as the first word: 1 began, 2 changed, 3 ended, 4 cancelled. A state outside these is not reported.
- The values are measured since the gesture began: a pan reports its translation in points, rounded; a pinch reports its scale in thousandths; a rotation reports its angle in thousandths of a radian. A swipe reports its direction as the first word: 1 left, 2 right, 3 up, 4 down.
- The target that receives the recognizers' actions is retained by the recognizers, so it lives as long as the control's recognizers do.

## Invariants

- Every recognizer and its target are created and attached on the thread that runs the program.
- The event's tag is the tag of the GESTURES instruction that attached the recognizer.
- A mask of 32 or more is a stream defect, because no recognizer bit lies above 16.

## Negative Logic

- No recognition is tuned here. Thresholds, simultaneity and exclusivity are the platform's defaults.
- No application logic. The header never reads what a gesture means.
- No event for a phase outside the four codes.
- Refusal: a mask of 32 or more ends the process with a message naming the defect. Bits inside the range that name no recognizer are ignored.

## Dependencies and consumers

Depends on UIKit and the Objective-C runtime for the attached recognizers, and on [[iOS Host Events]] for the queue. Included by [[iOS Host Adapter]]. Its instruction is encoded by [[Std Mobile Stream]], its values decoded by [[Std Mobile Gesture]] through [[Std Mobile View]], and its self-test is run by [[iOS Host Capability Test]].

## Resolved Grill Log

- **Q:** How is recognition tested without synthetic touches? **A:** Recognizers and the self-test report through one fire path, so the test covers the queue and Pudu decoding; UIKit's own recognition is not re-tested. _Rejected:_ injecting touch events, which would test the simulator's input path rather than this header.
- **Q:** Why round to whole points and thousandths here? **A:** The program reads integers. Rounding happens once at the host's edge, so no float crosses the boundary. See [[Std Mobile Gesture]].
- **Q:** Why does a second GESTURES instruction replace the set rather than add to it? **A:** A control has one tag, and a second attachment is a change of its recognizers. Adding to the set would keep recognizers the program no longer asked for.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Gesture]] · [[Native iOS Capabilities Delivery]]
