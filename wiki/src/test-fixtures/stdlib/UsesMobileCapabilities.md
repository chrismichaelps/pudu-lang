---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileCapabilities.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native]
aliases: [Uses Mobile Capabilities]
---

# Uses Mobile Capabilities

## Purpose and interface

Stdlib fixture for the capability additions of [[Std Mobile View]]: the instructions of [[Std Mobile Stream]] that carry them, and the event decoding of [[Std Mobile Decode]], including the words of measured events. Its entry drives `mount` and `update` through the checks below and answers the number of checks that held. It answers 16, asserted by the data spec.

The fixture checks:
1. The stream words of every new instruction: GESTURES, ALERT, VALUE, HAPTIC, TRAITS, ACCESS_HINT, ACCESS_VALUE, MENU and ANIMATE.
2. The kinds of `Progress` and `Activity`: CREATE kind 10 and kind 11.
3. The event decoding of every new event kind: GESTURED (9), CHOSE (10), RESIZED (11), LIFECYCLE (12) and PICKED (13), with their text, detail and words.
4. That a negative signed word decodes as negative, through `signed`, and that a word with its top bit set folds below zero.
5. The reconcile behavior of each new wrapper: a changed `Progress` value writes one VALUE; a changed recognizer set writes one GESTURES; an `Accessible` change writes only the changed fields; a changed `Menu` writes one MENU; an `Animated` group writes nothing on update; and a changed wrapper kind replaces its node.

The fixture runs interpreted and as native C11 code, and both must agree.

## Invariants

- Each check compares an exact word or byte sequence, never a length alone.
- The fixture makes no foreign call. The host side of each instruction is checked by the simulator run of [[Native Showcase Example]], not here.

## Negative Logic

- No platform host is started, so the fixture runs without a simulator.
- Checks do not depend on the order of the platform's own default colors or traits.
- Decoding is checked on the values the host would write, not on a live event.

## Dependencies and consumers

Depends on [[Std Mobile View]], [[Std Mobile Decode]], [[Std Mobile Stream]], [[Std Mobile Gesture]], [[Std Mobile Scene]], [[Std Mobile Access]] and [[Std Mobile Feedback]]. Its checks mirror the contracts that [[iOS Host Gesture]], [[iOS Host Feedback]], [[iOS Host Access]], [[iOS Host Scene]] and [[iOS Host Motion]] realize.

## Resolved Grill Log

- **Q:** Check bytes or summaries? **A:** Exact words, as for [[Uses Mobile Material]]. A summary such as "contains a GESTURES" would pass a wrong mask or a wrong node id.
- **Q:** Why check decoding of each kind here rather than only on the simulator? **A:** Decoding is pure, so it is checked where it runs fastest and without a platform. The simulator run checks that the host writes what this decoding expects.
- **Q:** Why check a changed field alone? **A:** A change to one field must write exactly that one instruction. A combined check would hide a commit that rewrote the whole control.

## Referenced by

[[Native iOS Capabilities Delivery]]
