---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Integer/Word128.hs"
fidelity: Active
aliases: [Backend Word128 Kernel]
---
# Backend Word128 Kernel

Export word128Runtime, word128RuntimeParts and word128RuntimeDependencies.
Data.Text is the sole dependency. The complete runtime concatenates the
ordered catalogue; the dependency query returns value for known helpers,
plus zero/left/compare/sub for division, and no dependencies for value or
unknown names. C definitions precede consumers and use static inline linkage.

Implement [[Native Word128 Kernel Contract]]: two-word zero/comparison,
carry addition, modular subtraction, safe shifts, full-product overflow and
bounded quotient/remainder. No headers, IO, allocation or language admission.

## Resolved Grill Log

- Both high-word carries contribute to addition overflow.
- Four 32-bit limbs keep each multiplication accumulator within uint64_t.
- Every shift count is guarded before a C shift expression executes.
- Long division preserves the 129th remainder bit before reduction.
- Selectable dependencies retain the complete compatibility view unchanged.

## Dependencies and consumers

[[Native Word128 Kernel Contract]] · [[Pudu Cabal Manifest]]

## Referenced by

[[src/_MOC]] · [[Native Wide Value Publication]]
