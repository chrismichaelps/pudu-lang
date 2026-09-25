---
type: module
path: "@root/test-fixtures/stdlib/UsesHumanAll.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, text]
aliases: [Uses Human All]
---

# Uses Human All

## Purpose and interface

Executable fixture for [[Std Human]]. Its `main` returns 44 held assertions reaching every export.

Byte sizes read in both unit families and every case; each refusal and its sentence, including a
fraction of a byte, an unknown unit, a missing number, overflow in the number and in the product,
and too many fraction digits; sizes written at unit boundaries, at `Int`'s limits, and where
rounding reaches the next unit. Durations read compact, spaced, fractional, signed, and from
`Time.describe`; refused for unknown units, a missing unit, partial milliseconds, and overflow of
a single pair and of the sum; written exactly and read back. Ordinals with teens and negatives,
plurals given explicitly, and relative time on both sides of a fixed reference, truncated.

## Grill Log

- **Q:** Use the clock for `relative`? **A:** No. _Rationale:_ a fixed reference instant makes every
  answer a constant the fixture can state.

## Referenced by

[[Std Human]] · [[Runtime Evaluation Spec]]
