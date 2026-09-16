---
type: module
path: "@root/src/Pudu/Eval/Foreign/Result.hs"
fidelity: Active
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, ffi]
aliases: [Eval Foreign Result]
---

# Eval Foreign Result

## Purpose and interface

`convertForeignValue` converts non-owning native results and slot values through the declared
crossing. `ConversionFailure` distinguishes missing text from a representation mismatch. Conversion
is pure: no native calls, claims, cleanup, or global state occur here.

## Contract and algorithm

Integers are accepted only for integer crossings with valid widths and values; UInt64 restores the
unsigned interpretation of its carrier. Floats are accepted only for floating crossings. Records
require exact nominal name, field count, and field-name order, and recursively convert every field.
No truncating zip or generic scalar fallback accepts a different declared shape. Record fields
cannot introduce handles, bytes, or unit. Handles are constructed only by the generation-aware owner.

## Covered by

`Pudu.Eval.Foreign.ResultSpec` holds each refusal: a carrier of the wrong category, a record short a
field, one carrying a surplus or renamed field, one whose fields arrive in another order, a field
declared as a handle, run of bytes, or unit, an integer outside its declared width, and a width the
boundary does not carry. It also holds what must still convert, so the refusals cannot be satisfied
by refusing everything: a nested record at every depth, and a UInt64 whose carrier arrives negative.

## Grill Log

- **Q:** Convert any integer-shaped carrier to an integer value? **A:** No; the declared crossing
  must be integral. A native carrier cannot override the checked result type.
- **Q:** Rebuild only the record fields that happen to be present? **A:** No; incomplete or surplus
  fields are a boundary mismatch, never a smaller successful record.

## Dependencies and consumers

Requires [[Foreign Call]], [[Foreign Crossing]], [[Eval Value]], [[Float Literal]], and
[[Integer Literal]]. Consumed by [[Eval Foreign]].

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Foreign]] · [[Pudu Cabal Manifest]]
