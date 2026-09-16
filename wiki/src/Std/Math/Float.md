---
type: module
path: "@root/lib/Std/Math/Float.pudu"
fidelity: Active
tags: [module, stdlib, math, float, trigonometry]
aliases: [Std Math Float]
---
# Std Math Float

## Purpose

Provide high-performance, hardware-close IEEE-754 64-bit double-precision floating-point mathematics:
trigonometric functions, exponentials, natural and base-2/base-10 logarithms, hyperbolic curves,
floating-point decomposition and classification, and mathematical constants.

## Interface

### Constants
- `pi() -> Float`: Mathematical constant $\pi \approx 3.14159265358979323846$.
- `tau() -> Float`: Circle constant $\tau = 2\pi \approx 6.28318530717958647692$.
- `e() -> Float`: Euler's number $e \approx 2.71828182845904523536$.
- `ln2() -> Float`: Natural logarithm of 2 $\approx 0.6931471805599453$.
- `ln10() -> Float`: Natural logarithm of 10 $\approx 2.302585092994046$.
- `sqrt2() -> Float`: Square root of 2 $\approx 1.4142135623730951$.
- `epsilon() -> Float`: Machine epsilon for 64-bit float ($2^{-52} \approx 2.220446049250313 \times 10^{-16}$).

### Trigonometric Functions
- `sin(x: Float) -> Float`: Sine of radians using range reduction to $[-\frac{\pi}{4}, \frac{\pi}{4}]$ and minimax polynomial.
- `cos(x: Float) -> Float`: Cosine of radians using range reduction.
- `tan(x: Float) -> Float`: Tangent $\sin(x) / \cos(x)$.
- `asin(x: Float) -> Option[Float]`: Arc sine in $[-\frac{\pi}{2}, \frac{\pi}{2}]$, returning `None` if $|x| > 1$.
- `acos(x: Float) -> Option[Float]`: Arc cosine in $[0, \pi]$, returning `None` if $|x| > 1$.
- `atan(x: Float) -> Float`: Arc tangent in $(-\frac{\pi}{2}, \frac{\pi}{2})$.
- `atan2(y: Float, x: Float) -> Float`: Four-quadrant inverse tangent.

### Exponentials & Logarithms
- `exp(x: Float) -> Float`: $e^x$ using range reduction $x = k \ln 2 + r$ and Taylor polynomial on $|r| \le \frac{\ln 2}{2}$.
- `ln(x: Float) -> Option[Float]`: Natural logarithm $\ln(x)$, returning `None` if $x \le 0$.
- `log2(x: Float) -> Option[Float]`: Base-2 logarithm $\log_2(x) = \ln(x) / \ln(2)$.
- `log10(x: Float) -> Option[Float]`: Base-10 logarithm $\log_{10}(x) = \ln(x) / \ln(10)$.
- `powf(base: Float, exponent: Float) -> Option[Float]`: $x^y = \exp(y \ln x)$, or exact integer powers for whole numbers.
- `sqrt(x: Float) -> Option[Float]`: Square root via Newton-Raphson iteration. `None` if $x < 0$.
- `cbrt(x: Float) -> Float`: Cube root $\sqrt[3]{x}$ via Halley's iteration, preserving sign.
- `hypot(x: Float, y: Float) -> Float`: Euclidean distance $\sqrt{x^2 + y^2}$ scaled to avoid intermediate overflow/underflow.

### Hyperbolic Functions
- `sinh(x: Float) -> Float`: Hyperbolic sine $(e^x - e^{-x}) / 2$.
- `cosh(x: Float) -> Float`: Hyperbolic cosine $(e^x + e^{-x}) / 2$.
- `tanh(x: Float) -> Float`: Hyperbolic tangent $(e^{2x} - 1) / (e^{2x} + 1)$.

### Rounding & Decomposition
- `floor(x: Float) -> Float`: Greatest integer not greater than $x$.
- `ceil(x: Float) -> Float`: Smallest integer not less than $x$.
- `round(x: Float) -> Float`: Rounds half away from zero.
- `trunc(x: Float) -> Float`: Integer part, discarding fractional bits.
- `fract(x: Float) -> Float`: Fractional part $x - \operatorname{trunc}(x)$.
- `copysign(magnitude: Float, sign: Float) -> Float`: Magnitude of first operand with sign of second.
- `isNan(x: Float) -> Bool`: Whether value is IEEE-754 NaN ($x \neq x$).
- `isInfinite(x: Float) -> Bool`: Whether value is positive or negative infinity.
- `isFinite(x: Float) -> Bool`: Whether value is neither NaN nor infinite.
- `radians(deg: Float) -> Float`: Degree to radian conversion ($deg \times \frac{\pi}{180}$).
- `degrees(rad: Float) -> Float`: Radian to degree conversion ($rad \times \frac{180}{\pi}$).
- `lerp(a: Float, b: Float, t: Float) -> Float`: Precise linear interpolation $a + t(b - a)$.

## Algorithm and boundaries

Range reduction maps large input angles into $[-\frac{\pi}{4}, \frac{\pi}{4}]$, preserving precision without trigonometric drift.
The polynomial coefficients follow Chebyshev minimax and Taylor polynomial approximations up to 13th order.
For `atan`, argument reduction applies $\arctan(x) = \frac{\pi}{4} + \arctan\left(\frac{x - 1}{x + 1}\right)$ for $x \in (\sqrt{2}-1, 1]$, and $\arctan(x) = \frac{\pi}{2} - \arctan(1/x)$ for $x > 1$, mapping all evaluation into $[-0.4142, 0.4142]$ and achieving precision within $< 10^{-7}$ everywhere while returning exact $\frac{\pi}{4}$ at $x = 1.0$.
All edge cases obey IEEE-754 standards: `sin`, `cos`, `tan` of $\pm\infty$ return NaN; `atan` of $\pm\infty$ yields $\pm\frac{\pi}{2}$; `exp(-\infty) = 0.0`; `ln(+\infty) = +\infty`; `powf(0.0, 0.0) = Some(1.0)`.
No panic is possible: out-of-domain mathematical operations return `Option[Float]` rather than panicking or producing invalid values.

## Grill Log

- **Q:** Why pure Pudu implementations instead of relying only on foreign C libm?
  **A:** Ensures cross-platform consistency, offline determinism, and validates that Pudu's floating-point semantics meet IEEE-754 precision guarantees everywhere without platform divergence.
- **Q:** Why does `ln(0.0)` or `sqrt(-1.0)` return `Option[Float]`?
  **A:** In Pudu, domain errors in standard library functions are explicitly typed as absence (`None`) rather than silent NaN propagation or unhandled aborts.
- **Q:** How is `atan2` guarded against division by zero and infinite operands?
  **A:** It inspects quadrant signs, zero components, and infinite operands directly, correctly mapping axes $(\pm \frac{\pi}{2}, 0, \pm\pi)$ and diagonally infinite directions $(\pm\frac{\pi}{4}, \pm\frac{3\pi}{4})$ without division by zero.
- **Q:** How does `atan` achieve high precision at $x = 1.0$?
  **A:** Argument reduction converts $x = 1.0$ into $\frac{\pi}{4} + \arctan\left(\frac{1 - 1}{1 + 1}\right) = \frac{\pi}{4} + \arctan(0) = \frac{\pi}{4}$ exactly.

## Referenced by

[[src/Std/_MOC]] · [[Std Math]] · [[architecture/STDLIB]]
