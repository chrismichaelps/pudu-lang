---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer/Word128.hs"
fidelity: Active
aliases: [Backend Word128 Kernel]
grammar: "[[grammar/haskell]]"
---
# Backend Word128 Kernel

## Purpose and interface

Export word128Runtime :: [Text], a pure ordered C11 kernel used by the later
Int128/UInt128 runtime adapter and actual compiled tests. Data.Text is the only
import; no source syntax, semantic analysis, evaluator, IO or new dependency.

## Algorithm and invariants

Implement [[Native Wide Integers]]: two uint64_t words, zero/compare, carry
addition, modular subtraction, bounded safe left/right shifts, full product
overflow detection using four 32-bit limbs and bounded quotient/remainder with
an explicit zero-divisor result. Functions have pudu_word128_ names and static
inline linkage. Definitions precede their consumers. The kernel emits no
headers; callers provide stdint.h. No global state or allocation.

## Resolved Grill Log

- **Q:** Lose carry when high words overflow before low carry is added? **A:** Track both carries and OR them.
- **Q:** Can product accumulation overflow uint64_t? **A:** A product plus result limb plus carry is at most 2^64-1.
- **Q:** Shift by 64 or 128? **A:** Separate zero, subword, crossword and out-of-range paths before every C shift.
- **Q:** Divide by zero or drop the 129th remainder bit? **A:** Return an explicit zero flag, and preserve the extra bit before reduction.
- **Q:** Change existing scalar ABI now? **A:** No; production selection and typed admission are later integrations.

## Dependencies and consumers

[[Native Wide Integers]] · [[Native Word128 Tests]] · [[Pudu Cabal Manifest]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Wide Integer Delivery]]
