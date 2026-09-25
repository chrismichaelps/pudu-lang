---
type: module
path: "@root/test-fixtures/stdlib/RejectsToTextMisuse.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, language, diagnostics]
aliases: [Rejects To Text Misuse]
---

# Rejects To Text Misuse

## Purpose and interface

Must-fail fixture: a `toText()` result bound as `Int` is `E3001`, and `toText(1)` is `E3003`.

## Referenced by

[[Standard Library Program Spec]] · [[Type Check Rule]]
