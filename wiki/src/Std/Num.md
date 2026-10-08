---
type: module
path: "@root/lib/Std/Num.pudu"
fidelity: Active
tags: [module, stdlib, numeric]
aliases: [Std Num]
---
# Std Num

## Purpose and interface

Name the independent numeric capabilities `Zero`, `One`, `Add`, `Sub`, `Mul`, `Rem`, `Div`
and `Integer`. Export `sum`, `sumOr`, `product`, `runningSum`, `spread`, `two` and `small`.
Implement the capabilities for the supported integer types and both floating widths.

## Algorithm and contracts

`sum` and `product` return `None` on empty input; `sumOr` returns its supplied empty value.
`runningSum` returns an empty array for empty input and includes the additive identity for
nonempty input. `spread` subtracts the supplied extrema. `two` and `small` construct values
through capability operations. Division and remainder return `None` for zero divisors.
`Integer.toBigInt` widens exactly; `fromBigInt` refuses values outside the selected width.
Private `widenInteger` treats refusal to widen an integer as an implementation defect.

## Resolved Grill Log

The explicit primitive implementations use Pudu's built-in arithmetic and supply the leaf
capabilities that generic numeric algorithms call. Pudu supports derive strategies for aggregate
types; these implementations do not imply their absence. This issue changes documentation only.
The source comment and generated documentation must give the same explanation; public identities
and all executable source remain unchanged. Bounds stay independent: an algorithm requires only
the capabilities it uses. Overflow and operator behavior remain governed by [[Semantics]].

## Dependencies and referenced by

Built-in numeric operations only. [[src/Std/_MOC]] · [[src/_MOC]] · [[Std Order]] ·
[[2026-10-07-derive-documentation]]
