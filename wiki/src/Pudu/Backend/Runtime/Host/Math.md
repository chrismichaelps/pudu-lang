---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Math.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Math]
---
# Native Host Math

Export the family's runtime parts and their prerequisites.

The binary64 kernels, each the platform math library's own function. `hostMathFunctions` is the one list lowering and emission both read.

## Resolved Grill Log

The functions are the ones the interpreter calls, so results agree to the bit on one platform. A kernel whose last bit belongs to the library (`cbrt`, the trigonometric, exponential, logarithmic and hyperbolic functions, `pow`, `hypot`) reads its operands through volatile storage: a C compiler otherwise works a call with written operands out itself, correctly rounded, where the library the interpreter calls may answer one bit away (`cbrt(27.0)` on glibc). Rejected: disabling built-in functions for the whole program, which slows every copy and comparison. The correctly rounded kernels (`sqrt`, `floor`, `ceil`, `trunc`, `round`, `fma`) stay direct.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]]
