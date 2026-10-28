---
type: module
path: "@root/test-fixtures/ark/UsesArkMath.pudu"
fidelity: Active
aliases: [Ark Math Fixture]
tags: [module, ark, test]
---
# Ark Math Fixture

## Purpose and interface

Executable UsesArkMath module importing shipped [[Ark Math]]. Main returns zero and prints exactly
`ark math: ok` after checking arithmetic, dot symmetry, cross orientation/orthogonality,
length, zero/non-finite rejection, and tiny/huge normalization. Failed checks panic with the
case name. Relative error checks use a 1e-12 tolerance and reject NaN through comparison.

## Resolved Grill Log

- **Q:** Test only ordinary unit vectors? **A:** No; 1e-300, 1e300, maximum finite values,
  subnormal components, signed zero, NaN and infinity protect scale-first behavior.
- **Q:** Depend on printed float formatting? **A:** No; checks are numeric and output is exact text.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math]] · [[Ark Math Gate]]
