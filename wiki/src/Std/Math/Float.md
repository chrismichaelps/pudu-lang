---
type: module
path: "@root/lib/Std/Math/Float.pudu"
fidelity: Active
tags: [module, stdlib, math, float, trigonometry]
aliases: [Std Math Float]
---
# Std Math Float

## Purpose

Provide IEEE 754 binary64 mathematics backed by [[Runtime Float Kernels]]: rounding,
square root, fused multiply-add, bit casts, trigonometry, exponentials, logarithms, powers and
hyperbolic functions, plus classification helpers and constants. Every public signature and
domain contract is stated here; the runtime computes, this module decides what is defined.

## Interface

### Constants
- `pi`, `tau`, `e`, `ln2`, `ln10`, `sqrt2` — nearest binary64 values; `epsilon()` is 2^-52.

### Exact kernels (bit-identical on every IEEE 754 platform)
- `sqrt(x) -> Option[Float]`: correctly rounded; `None` for negative or NaN input; signed zero
  and positive infinity return themselves.
- `floor`, `ceil`, `trunc`: exact integral results, signs of zero preserved.
- `round(x)`: half away from zero, exact.
- `fract(x)`: `x - trunc(x)`.
- `fma(x, y, z)`: `x * y + z` rounded once.
- `toBits(x) -> UInt64`, `fromBits(bits) -> Float`: binary64 encoding reinterpretation.
- `fromInt(n) -> Float`: nearest binary64, ties to even; exact for |n| <= 2^53.
- `toInt(x) -> Option[Int]`: truncation toward zero; `None` for NaN, infinities or out of range.

### Platform kernels (platform math library accuracy, normally within one ULP)
- `sin`, `cos`, `tan`, `atan`, `atan2(y, x)`, `exp`, `cbrt`, `hypot(x, y)`, `sinh`, `cosh`, `tanh`.
- `asin`, `acos -> Option[Float]`: `None` when |x| > 1 or NaN.
- `ln`, `log2`, `log10 -> Option[Float]`: `None` when x <= 0 or NaN.
- `powf(base, exponent) -> Option[Float]`: `None` for a NaN operand, zero base with negative
  exponent, or negative base with non-integral exponent; `Some(1.0)` for a zero exponent.

### Pure helpers
- `abs`, `clamp`, `lerp`, `copysign`, `radians`, `degrees`, `isNan`, `isInfinite`, `isFinite`.

## Algorithm and boundaries

Each kernel-backed function is one guard (where a domain applies) and one prelude kernel call.
No loop, allocation or Buffer staging remains. Domain refusals are decided in Pudu before the
kernel runs, so the runtime never invents an error and NaN never escapes an `Option` contract.
Determinism: exact kernels are reproducible across platforms and are the basis for lockstep
simulation; platform kernels may differ in the last bit between C math libraries.
[[Square Root Range Gate]] checks correct rounding against host goldens across the full binary64
range. [[Root Kernel Benchmark]] measures the reciprocal-root bit estimate against `1 / sqrt`.

## Grill Log

- **Q:** Keep pure Pudu polynomial and Newton implementations? **A:** No. They were neither
  correctly rounded nor fast: `sqrt(1e300)` returned about 4.77e293, `trunc` looped per bit and
  `ln(1e300)` looped a thousand times. _Resolved:_ one kernel enumeration, unchanged signatures.
- **Q:** Does this lose cross-platform determinism? **A:** Only for platform kernels, which never
  had a bitwise guarantee. Exact kernels are now bit-identical everywhere; a deterministic
  transcendental mode belongs in the engine math layer, built from exact kernels.
- **Q:** Why does `ln(0.0)` or `sqrt(-1.0)` return `Option[Float]`? **A:** Domain errors are
  typed absence rather than silent NaN propagation or aborts.
- **Q:** Adopt the reciprocal-root bit estimate as the engine's normalization path? **A:** No.
  Measured against `1 / sqrt` on the kernel, both refinements are slower and less accurate.

## Referenced by

[[src/Std/_MOC]] · [[Std Math]] · [[architecture/STDLIB]] · [[Runtime Float Kernels]]
