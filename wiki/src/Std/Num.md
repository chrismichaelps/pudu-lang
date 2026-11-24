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

## Integer parsing

- `parseInt(text: Str) -> Option[Int]`: an optional `+` or `-`, then ASCII decimal digits and nothing else. Exact across the whole `Int` range, including the most negative value. Overflow and any other text answer `None`; the program does not stop.
- `parseIntIn(text: Str, radix: Int) -> Option[Int]`: the same shape for radix 2 to 36, with letters `a` to `z` read in either case. A radix outside 2 to 36 answers `None`.
- One pass over the characters. Each digit is folded into the magnitude as it is read, and the bound is checked before each step.

## Resolved Grill Log

- **Q:** Why answer `None` instead of stopping on overflow or bad text? **A:** The text comes from outside the program, so a malformed value is an ordinary answer, not a defect. Callers decide what a missing number means.
- **Q:** How is the most negative `Int` reached without overflow? **A:** The magnitude is accumulated as a negative value. For a radix `r` and `INT_MAX = q·r + r0`, the largest magnitude is `q` then `r0 + 1` on the last digit, or `q + 1` then `0` when `r0 + 1` equals the radix. Both bounds fit, so the negative accumulation never passes the minimum.
- **Q:** Why one public parser? **A:** `Std.Text`, `Std.Cron`, `Std.Ui.Desktop` and `Std.Ui.Accessible` each carried a private copy. They now call `parseInt`. Desktop and Accessible previously capped at nine digits, so a larger number there now parses exactly. `Std.Text` keeps digits only, and `Std.Cron` keeps one to four digits, each as its own rule on top of the shared parser.

The explicit primitive implementations use Pudu's built-in arithmetic and supply the leaf
capabilities that generic numeric algorithms call. Pudu supports derive strategies for aggregate
types; these implementations do not imply their absence. This issue changes documentation only.
The source comment and generated documentation must give the same explanation; public identities
and all executable source remain unchanged. Bounds stay independent: an algorithm requires only
the capabilities it uses. Overflow and operator behavior remain governed by [[Semantics]].

## Dependencies and referenced by

Built-in numeric operations only. [[src/Std/_MOC]] · [[src/_MOC]] · [[Std Order]] ·
[[2026-10-07-derive-documentation]]
