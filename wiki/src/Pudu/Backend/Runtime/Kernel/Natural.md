---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Natural.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Natural Arithmetic]
---
# Native Natural Arithmetic

Export the family's runtime parts and their prerequisites.

Unsigned integers of any length as 32-bit limbs for the signature checks: reading big-endian bytes, comparison, addition, subtraction, multiplication, division with remainder, and modular multiplication, exponentiation and inversion.

## Resolved Grill Log

Schoolbook multiplication and limb-by-limb division are enough for one verification. No secret passes through here: verification holds only public values.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
