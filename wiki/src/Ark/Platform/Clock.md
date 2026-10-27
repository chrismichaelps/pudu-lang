---
type: module
path: "@root/lib/Ark/Platform/Clock.pudu"
fidelity: Active
aliases: [Ark Frame Clock]
tags: [module, ark, platform]
---
# Ark Frame Clock

## Purpose and interface

Fixed-step simulation timing from monotonic nanoseconds. `fixed(step, maxSteps, now) ->
Option[FrameClock]` (None for a non-positive step or step budget); `tick(clock, now) ->
(FrameClock, Tick)` adds the elapsed time and answers how many whole steps to simulate, the
interpolation fraction `alpha` in [0, 1) for rendering between states, the elapsed nanoseconds
and the nanoseconds dropped when more than `maxSteps` were owed. `untilNext(clock, now)` is the
time to the next step boundary, for pacing a pump. Pure: time is passed in, so tests are exact.

## Grill Log

- **Q:** Simulate with the measured frame time? **A:** No; variable steps make physics
  non-deterministic. Fixed steps plus interpolation decouple simulation from display rate.
- **Q:** Let a slow frame owe unbounded steps? **A:** No; capping steps and reporting the
  dropped time prevents the spiral where catching up makes every frame slower.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Platform Fixture]]
