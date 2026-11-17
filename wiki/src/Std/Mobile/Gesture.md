---
type: module
path: "@root/lib/Std/Mobile/Gesture.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile Gesture]
---

# Std Mobile Gesture

## Purpose and interface

Pure description of the gesture recognizers a control may carry and of the events they report. A control wrapped by `Recognizing` in [[Std Mobile View]] receives one recognizer per listed kind. Each recognizer reports a GESTURED event with its phase and values, and the module decodes those words into a `Gesture`. The module owns the bit of each kind in the GESTURES mask, the phase and direction codes, and the decoding table. It performs no I/O.

Exports:
- `type Kind = LongPress | Pan | Pinch | Rotation | Swipe`: the recognizers. Their mask bits are 1, 2, 4, 8 and 16 in that order.
- `type Phase = Began | Changed | Ended | Cancelled`: the state of a continuous gesture. Codes 1 to 4 in that order.
- `type Direction = Left | Right | Up | Down`: the direction of a swipe. Codes 1 to 4 in that order.
- `type Gesture = Pressed(Phase) | Panned(Phase, Int32, Int32) | Pinched(Phase, Int32) | Rotated(Phase, Int32) | Swiped(Direction)`: what a recognizer reported.
- `mask(kinds: &Array[Kind]) -> UInt32`: the GESTURES mask of a set of recognizers, the bitwise OR of their bits.
- `decoded(bit: UInt32, words: &Array[Int32]) -> Option[Gesture]`: the gesture that a recognizer bit and its words describe, or `None` for words the host never writes.

Units of each value:

| Gesture | Values | Unit |
| --- | --- | --- |
| `Pressed` | none | none |
| `Panned` | `x`, `y` translation since the gesture began | points |
| `Pinched` | scale since the gesture began | thousandths |
| `Rotated` | angle since the gesture began | thousandths of a radian |
| `Swiped` | direction | none |

## Invariants

- Recognizer bits are fixed by the constant table `KINDS`. A set of recognizers is their bitwise OR, and an empty set is zero.
- A phased gesture event carries three signed words: the phase code, then two values. A swipe carries one word, the direction code.
- Decoding is table driven. `DECODERS` maps each recognizer bit to its decoder; `PHASES` and `DIRECTIONS` map codes to values.
- A phased event with fewer than three words, or a phase code outside 1 to 4, decodes to `None`. A swipe with no word, or a direction code outside 1 to 4, decodes to `None`.
- Pressed reads only the phase. Pinched and Rotated read the first value. Panned reads both values.

## Negative Logic

- No recognition happens here. The platform recognizes a gesture; this module reads what it reported.
- No event is created here. The module never synthesizes a gesture.
- No range check on values. They pass through as the signed words the host wrote.
- No view, no control and no platform call. The recognizers are attached by [[iOS Host Gesture]].

## Dependencies and consumers

Depends on no other Std Mobile module. Consumers: [[Std Mobile View]], which carries `Gesture.Kind` in `Recognizing` and `Gesture.Gesture` in `Gestured`; [[Std Mobile Stream]], which receives the mask; the host [[iOS Host Gesture]]; the example [[Native Showcase Example]]; and the fixture [[Uses Mobile Capabilities]].

## Resolved Grill Log

- **Q:** Why fixed-point integers on the wire? **A:** Exact, platform-neutral values; no floating rounding crosses the boundary. The host rounds once, at its edge, and the program never sees a float.
- **Q:** Why report phases rather than only the final value? **A:** A continuous gesture changes many times. The program needs to know when it began and when it ended, so that work started by a press can be cancelled or completed. _Rejected:_ one event per gesture at its end.
- **Q:** Why one bit per recognizer kind? **A:** A control carries any subset of kinds, and one mask word names the set in one instruction. _Rejected:_ one instruction per recognizer.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Stream]] · [[iOS Host Gesture]] · [[Native iOS Capabilities Delivery]]
