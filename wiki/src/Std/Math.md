---
type: module
path: "@root/lib/Std/Math.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, math]
aliases: [Std Math]
---
# Std Math

## Purpose

Provide generic ordered whole-number algorithms through numeric traits rather than one concrete width,
supplemented by low-level, hardware-close integer bit manipulation routines (binary GCD, power of two,
integer logarithm).

## Interface

### Trait-generic Algorithms
- `min[T: Ord](left: T, right: T) -> T`: The smaller of two values.
- `max[T: Ord](left: T, right: T) -> T`: The larger of two values.
- `abs[T: Ord + Zero + Sub](value: T) -> T`: Distance from zero.
- `clamp[T: Ord](value: T, lower: T, upper: T) -> T`: Confine value to $[lower, upper]$.
- `between[T: Ord](value: T, lower: T, upper: T) -> Bool`: Inclusive range membership.
- `signum[T: Ord + Zero + One + Sub](value: T) -> T`: $-1$, $0$, or $1$ in value's type.
- `divide[T: Div](value: T, divisor: T) -> Option[T]`: Safe truncating division.
- `remainder[T: Rem](value: T, divisor: T) -> Option[T]`: Safe division remainder.
- `divMod[T: Div + Rem](value: T, divisor: T) -> Option[(T, T)]`: Quotient and remainder pair.
- `divides[T: Rem + Zero + Ord](divisor: T, value: T) -> Bool`: Exact divisibility test.
- `isEven[T: Rem + Zero + One + Add + Ord](value: T) -> Bool`: Even test.
- `isOdd[T: Rem + Zero + One + Add + Ord](value: T) -> Bool`: Odd test.
- `pow[T: One + Mul](base: T, exponent: Int) -> T`: Exponentiation by squaring.
- `checkedPow[T: One + Mul](base: T, exponent: Int) -> Option[T]`: Total power function.
- `gcd[T: Ord + Zero + One + Add + Sub + Rem](left: T, right: T) -> T`: Euclidean GCD.
- `lcm[T: Ord + Zero + One + Add + Sub + Mul + Div + Rem](left: T, right: T) -> T`: Least common multiple.
- `factorial[T: Ord + Zero + One + Add + Mul](value: T) -> T`: Factorial product.
- `isqrt[T: Ord + Zero + One + Add + Div](value: T) -> Option[T]`: Integer square root.
- `isPrime[T: Ord + Zero + One + Add + Mul + Rem](value: T) -> Bool`: Primality test.
- `digitCount[T: Ord + Zero + One + Add + Sub + Div](value: T) -> Int`: Decimal digit count.

### Low-level Hardware-close Integer Primitives
- `binaryGcd(u: Int, v: Int) -> Int`: Stein's algorithm computing greatest common divisor using bitwise shifts (`>> 1`) and subtractions without division or modulo.
- `isPowerOfTwo(n: Int) -> Bool`: Branchless power of two test: $n > 0 \land (n \ \& \ (n - 1)) == 0$.
- `nextPowerOfTwo(n: Int) -> Int`: Returns the smallest power of two $\ge n$.
- `ilog2(n: Int) -> Option[Int]`: Fast floor of $\log_2(n)$ using bit shifts. Returns `None` if $n \le 0$.
- `branchlessMin(a: Int, b: Int) -> Int`: Extrema selection via sign bit masking without conditional branches.
- `branchlessMax(a: Int, b: Int) -> Int`: Extrema selection without conditional branches.
- `branchlessAbs(n: Int) -> Int`: Absolute value via XOR and subtraction with arithmetic shift.

## Governance and algorithm

Partial numeric operations return `Option`; algorithms operate through declared `Std.Num` and `Std.Order` traits so caller widths are preserved.
Low-level integer routines exploit two's complement binary representation directly for maximum execution speed close to the metal.

## Grill Log

- **Q:** Why does division return `Option`? **A:** A zero divisor is an ordinary absent result here, not a hidden panic. _Rejected:_ partial library functions.
- **Q:** Why provide Stein's binary GCD alongside Euclidean GCD? **A:** Stein's algorithm replaces expensive hardware division (`div`/`idiv`) instructions with fast bit shifts and subtractions, executing several times faster on modern CPU pipelines.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Std Math Float]]
