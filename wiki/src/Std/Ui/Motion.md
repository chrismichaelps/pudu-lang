---
type: module
path: "@root/lib/Std/Ui/Motion.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, animation]
aliases: [Std Ui Motion]
---

# Std Ui Motion

## Purpose and interface

Animation as values: a `Transition` is a start value, a target, a start time, a duration, and an
easing curve, and its value at any millisecond is a pure function.

Exports:
- `type Easing = Linear | EaseIn | EaseOut | EaseInOut | Bezier(x1, y1, x2, y2) | Spring(stiffness, damping)`.
- `type Transition`; `transition`, `still`.
- `eased(easing, t)`, `valueAt(transition, now)`, `pixelAt(transition, now)`, `finished`.
- `retarget(transition, to, now)`: continues from the current value, so an interrupted animation
  never jumps.
- `frames(transition, frameMillis)`: sampled values, for tests and previews.

## Semantics

- Every curve answers 0 at the start and 1 at the end. Béziers are solved by bisection on x; a
  spring is the closed-form unit-mass damped oscillator over ten time units, overshooting when
  underdamped and settling monotonically when critically or over-damped.
- The state holds the transition; the view reads `valueAt(state.motion, now)`. Nothing animates
  behind the program's back, so a frame is reproducible from its time.

## Grill Log

- **Q:** Implicit animation attached to state changes? **A:** No. _Rationale:_ an implicit animation
  is a hidden clock inside the view layer; a transition value makes the animated quantity, its
  target, and its time visible and testable. _Rejected:_ animation as a view modifier.
- **Q:** Integer or float time? **A:** Integer milliseconds in, floats only for the curve, and
  `pixelAt` rounds once at the end.

## Dependencies and consumers

- Depends on [[Std Math Float]].
- Consumed by views that animate position, opacity, or size.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
