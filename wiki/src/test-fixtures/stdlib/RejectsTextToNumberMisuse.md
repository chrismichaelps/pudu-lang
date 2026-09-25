---
type: module
path: "@root/test-fixtures/stdlib/RejectsTextToNumberMisuse.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, language, diagnostics]
aliases: [Rejects Text To Number Misuse]
---

# Rejects Text To Number Misuse

## Purpose and interface

Must-fail fixture: `"8080".toInt()` bound as `Int` is `E3001` (it is an `Option`), and
`toFloat(10)` is `E3003`.

## Referenced by

[[Standard Library Program Spec]] · [[Type Check Rule]]
