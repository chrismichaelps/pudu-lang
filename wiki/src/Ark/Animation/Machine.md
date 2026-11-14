---
type: module
path: "@root/lib/Ark/Animation/Machine.pudu"
fidelity: Active
aliases: [Ark Animation Machine]
tags: [module, ark, animation]
---

# Ark Animation Machine

## Purpose and interface

`State` names a clip, a wrap mode and a non-negative finite speed; `Transition` names a source
state, an event, a target state and a non-negative finite fade in seconds. `build(states,
transitions, initial) -> Result[Machine, Error]` refuses duplicate states or transitions, unknown
states, invalid speeds/wraps/fades and clips with differing joint counts.

`trigger(machine, event)` follows the current state's transition, restarting the target at time
zero and keeping the previous playback to fade out; an event with no transition leaves the
machine unchanged (`accepts` asks first). `advance(machine, seconds)` moves both clocks by their
state's speed and ends a fade once its duration has elapsed. `pose(machine)` samples the current
state and, while fading, blends from the previous state's pose by elapsed / fade.

## Invariants

- The machine is a value; triggering and advancing return new machines.
- A zero fade switches immediately; the faded-out clip keeps its own clock during a fade.
- Transitions are keyed by (state, event) tuples, so lookup is one map access per event.

## Resolved Grill Log

- **Q:** Treat an unhandled event as an error? **A:** No; games broadcast input events to every
  animated entity, most of which ignore most events. `accepts` exists for callers who care.
- **Q:** Freeze the outgoing clip during a fade? **A:** No; a frozen pose reads as a hitch.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Animation]] · [[Ark Animation Fixture]]
