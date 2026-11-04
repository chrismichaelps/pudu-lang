---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer/Big/Operations.hs"
fidelity: Active
aliases: [Backend BigInt Operations]
grammar: "[[grammar/haskell]]"
---
# Backend BigInt Operations

## Purpose and interface

Export bigOperationRuntimeParts and bigOperationRuntimeDependencies: the
BigInt helpers in the frame emitter's integer ABI (`pudu_big_add(a, b,
kind, site)` and the rest, named by [[Backend Emit Support]]'s `big_`
prefix), the entry exit status, decimal display, and conversions to and
from the one- and two-word integer kinds.

## Algorithm and invariants

- Checked, wrapping and saturating forms are all exact: a BigInt has no
  interval to overflow, wrap into or clamp to. The kind and overflow site
  arguments are taken and ignored.
- `/` and `%` fail at the division-by-zero site when the divisor is zero.
- A shift count is an Int; a negative one fails at the negative-shift
  site.
- The exit status is 0 for zero, 1 for a negative value, 255 above 255,
  and the value otherwise, as for every integer entry.
- A conversion to a fixed kind is checked first by `big_fits_int` or
  `big_fits_wide` against that kind's ends.

The parts come after the text parts in [[Backend Runtime]] because
`pudu_text_display_big` returns text.

## Referenced by

[[Native BigInt]] · [[Backend BigInt Values]] · [[src/Pudu/Backend/_MOC]]
