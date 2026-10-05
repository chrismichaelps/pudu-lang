---
type: module
path: "@root/lib/Std/Show.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, derive]
aliases: [Std Show]
---

# Std Show

## Purpose and interface

Rendering helpers (`render`, `text`, `int`, `array`, `table`, …) and the
`Show` trait: `show(self: &Self) -> Str`. Every wired-in scalar renders as the
prompt renders it; `Array[A]` and `Option[A]` render through their elements.
`derive Show` renders a record as `Name{field: value, …}` and a sum as its
variant: a unit variant by name, a positional payload in parentheses, a named
payload as a record is.

## Invariants

Text keeps its quotes, so a rendered `"1"` is never mistaken for the number.
Fields and variants render in declaration order. Derived output equals the
prompt's rendering for records, unit variants and positional variants; named
variant payloads show their field names, which the prompt omits.

## Grill Log

- **Q:** Reuse the prelude `show` inside the derive? **A:** No; fields render
  through their own `Show`, so a type may give itself a reading of its own.
- **Q:** Decide positional against named payloads at run time? **A:** The
  derive tests the first field's name, which folds per field.

## References

[[Derive Design]] · [[Std Meta]] · [[src/Std/_MOC]]
