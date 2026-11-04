---
type: module
path: "@root/lib/Ark/Math/Random.pudu"
fidelity: Active
aliases: [Ark Random]
tags: [module, ark, math]
---
# Ark Random

## Purpose and interface

`Rng` is SplitMix64 state. `seeded(seed)`, `next(rng) -> (Rng, UInt64)`, `unit(rng) -> (Rng,
Float64)` in [0, 1) with 52 random mantissa bits built by bit cast, `between(rng, low, high)`
and `below(rng, bound) -> (Rng, Int)` (unbiased rejection). Only wrapping integer operations and
exact bit casts are used, so sequences are bit-identical on every platform.

Binary64 throughout with written operation order; degenerate input answers `None`, never NaN.
Depends on [[Ark Math]] and [[Std Math Float]] only, within layer zero.

## Grill Log

- **Q:** Reuse Std.Random? **A:** Engine simulation needs a stated algorithm and a float path
  without conversion loops; SplitMix64 is small, fast and statistically adequate for games.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math]] · [[Ark Math Extended Fixture]]
