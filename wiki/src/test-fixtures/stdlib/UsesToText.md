---
type: module
path: "@root/test-fixtures/stdlib/UsesToText.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, language, text]
aliases: [Uses To Text]
---

# Uses To Text

## Purpose and interface

Executable fixture for the universal `toText()` method in [[grammar/pudu]]. Its `main` returns 12
held assertions: integers of two widths and a negative, a float, a flag, a decimal keeping its
scale, text, a character, unit; arrays with and without text, a map, a set in key order, a range, a
tuple; a record, variants, and the wired-in carriers; agreement with interpolation; a declared
`toText` winning directly and through an unbounded type parameter; the method bound as a value;
and bytes keeping their `Option` form, including invalid UTF-8.

## Grill Log

- **Q:** Compare against `display` computed in the fixture? **A:** Against literal text, and once
  against interpolation. _Rationale:_ comparing two calls into one renderer proves only agreement.

## Referenced by

[[Runtime Evaluation Spec]] · [[Eval Operator Access]] · [[Type Check Rule]]
