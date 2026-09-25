---
type: module
path: "@root/test-fixtures/stdlib/UsesTextToNumber.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, language, text, numeric]
aliases: [Uses Text To Number]
---

# Uses Text To Number

## Purpose and interface

Executable fixture for `toInt`, `toFloat`, and `toDecimal` on text. Its `main` returns 14 held
assertions: signs and leading zeros; `Int`'s exact bounds and one past each; refusals for empty text,
a bare sign, surrounding space, separators, a point, a radix prefix, and non-ASCII digits; floats with
a leading or trailing point, exponents, `0.1`, a subnormal, and refusals of overflow, `inf`, `nan`,
a bare point or exponent, a second point, space, and a comma; decimals keeping their scale and
refusing separators and space; and writing then reading answering the value written.

## Referenced by

[[Eval Builtin TextNumber]] · [[Runtime Evaluation Spec]]
