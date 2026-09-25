---
type: module
path: "@root/lib/Std/Concurrent/Retry.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, concurrency]
aliases: [Std Concurrent Retry]
---

# Std Concurrent Retry

## Purpose and interface

Retrying fallible work with exponential backoff and jitter, outside HTTP.

- `type Jitter = NoJitter | FullJitter | EqualJitter`.
- `type Policy = { attempts, initialMillis, maxMillis, multiplier, jitter }`; `standard()` is five
  attempts from 100 ms doubling to 10 s with full jitter. A caller changes fields with a record update.
- `type RetryError[E] = GaveUp(Int, E) | Stopped(Cancel.Reason) | Invalid(Str)`.
- `validate(policy) -> Result[(), Str]`.
- `ceiling(policy, retry) -> Int`: the un-jittered wait before retry `retry` (1 is the wait after
  the first failure).
- `delay(policy, retry, generator) -> (Random.Generator, Int)`: the jittered wait.
- `run(policy, action)`, `runWhen(policy, retryable, action)`,
  `runCancellable(policy, token, retryable, action)`: `action` receives the attempt number from 1.

## Semantics

- `ceiling` multiplies only while the result stays below the cap, checking `delay > max / multiplier`
  before multiplying, so it saturates at `maxMillis` and never overflows.
- Full jitter draws uniformly from `[0, ceiling]`; equal jitter from `[ceiling / 2, ceiling]`.
- A policy is refused before the first attempt when `attempts < 1`, `initialMillis < 0`,
  `maxMillis < initialMillis`, or `multiplier < 1`.
- `runCancellable` checks its token before every attempt and waits through `Cancel.pause`.

## Grill Log

- **Q:** Multiply then clamp? **A:** No. _Rationale:_ the product overflows before the clamp sees
  it, and a negative cap turns every wait negative. _Rejected:_ post-multiplication clamping.
- **Q:** One entry point with optional hooks? **A:** Three functions. _Rationale:_ a record of
  optional functions reads worse at the call than a name that says what is retried.

## Referenced by

[[src/Std/_MOC]] · [[Std Concurrent]] · [[Uses Concurrent Coordination]]
