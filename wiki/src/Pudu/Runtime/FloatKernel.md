---
type: module
path: "@root/src/Pudu/Runtime/FloatKernel.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance, math]
aliases: [Runtime Float Kernels]
---

# Runtime Float Kernels

## Purpose, interface and invariants

Implements every [[Float Kernel Identity]] entry for [[Std Math Float]]. The enumeration, names
and shapes live in that leaf module so the checker never depends on this runtime layer.

```haskell
applyFloatUnary   :: FloatKernel -> Double -> Double
applyFloatBinary  :: FloatKernel -> Double -> Double -> Double
applyFloatTernary :: FloatKernel -> Double -> Double -> Double -> Double
```

- **Exact kernels.** `sqrt`, `floor`, `ceil`, `trunc`, `round`, `fma`, `toBits` and `fromBits`
  are IEEE 754 correctly-rounded or exact operations. They give identical bits on every
  conforming platform and are the deterministic basis for engine math. `sqrt` lowers to the
  hardware square-root instruction; the others are the C math library's exact routines.
- **Platform kernels.** Trigonometric, exponential, logarithmic, power, `cbrt`, `hypot` and
  hyperbolic kernels call the platform math library. Results are accurate to its documented
  bound (normally within one ULP) but are not promised bit-identical across platforms.
- `round` is half away from zero, matching [[Std Math Float]]'s documented contract.
- Kernels are total on binary64: NaN, infinities and signed zeros follow IEEE 754 and C99
  Annex F. Domain refusals (`None`) stay in Pudu, so the runtime never invents an error.
- Bit casts reinterpret the binary64 encoding as an unsigned 64-bit word and back; no value
  conversion occurs. Out-of-range words are refused by the caller's type, never truncated here.
- Calls are `unsafe` foreign calls: no allocation, no callback into the runtime, no blocking.
  The module has no evaluator or frontend dependency.

## Grill Log

- **Q:** Keep the binary64 functions as Pudu loops? **A:** No. Measured interpreted `sqrt` cost
  about nine microseconds per call, `trunc` loops per bit, and `ln` loops once per halving (a
  thousand iterations for `1e300`). Engine math needs hardware operations with exact results.
  _Resolved:_ one kernel enumeration backs the public functions; signatures are unchanged.
- **Q:** One builtin per operation or one per arity with an operation code? **A:** One builtin
  constructor carrying a `FloatKernel`. Names stay readable (`floatSqrt`), dispatch is a single
  case, and the evaluator, checker and resolver cannot disagree about which kernels exist.
- **Q:** Do platform transcendentals break deterministic simulation? **A:** They may differ in
  the last bit across C libraries. _Resolved:_ exact kernels are documented as deterministic;
  a deterministic transcendental mode is built from exact kernels by the engine math layer.
- **Q:** Emit an error for a negative square root? **A:** No; the kernel returns NaN and
  [[Std Math Float]] maps the domain to `None` before calling it.

## Dependencies and consumers

[[Eval Builtin Numeric]] dispatches `FloatKernelBuiltin` here by shape; [[Std Math Float]] is the
public surface. Names and shapes come from [[Float Kernel Identity]].

## Referenced by

[[src/_MOC]] · [[Std Math Float]] · [[Square Root Delivery]]
