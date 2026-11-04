---
type: module
path: "@root/src/Pudu/Backend/Runtime/Char.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Char Runtime]
---
# Native Char Runtime

## Purpose and interface

Export charRuntimeParts and charRuntimeDependencies. A Char is a `uint32_t`
Unicode scalar; checked programs never hold a surrogate or anything past
U+10FFFF, so no helper validates its argument.

| Part | C entry point | Evaluator source |
| --- | --- | --- |
| char_text | `pudu_char_text(c)`, a new one-scalar text | callDisplay, CharToText |
| char_show | `pudu_char_show(c)`, quoted as renderValue quotes | renderValue on CharValue |
| print_char | `pudu_print_char(c)`, the scalar and a newline | print of a fused display |
| text_char_at | `pudu_text_char_at(text, index, site)` | charAtFast |

`char_show` escapes exactly what `escape` escapes (backslash, double quote,
tab, newline) and writes a single quote as `'\''`, the one special case
`renderValue` adds. Every other scalar, including other control characters,
is written as itself.

`text_char_at` fails at its E7004 site when the index is negative or not
below the scalar count, which is where `charAtFast` and `scalarOffset` both
end up; otherwise it decodes the scalar at that position.

## Negative logic

No Char arithmetic and no conversion from Int: `charFromCode` answers an
Option, which native does not represent yet. No locale, no wide-character
libc calls.

## Grill Log

- **Q:** Why a separate `uint32_t` cell member rather than the `int` Bool
  uses? **A:** C11 only promises 16 bits for `int`; a scalar needs 21.
  _Rejected:_ storing Char in the integer carrier, which would make every
  comparison go through the signed-magnitude helpers.
- **Q:** Does `print_char` duplicate `char_text` plus `print_text`? **A:** It
  writes the encoded bytes straight to stdout without allocating, the same
  fusion `print(display(n))` gets for integers.

## Referenced by

[[Native Text Runtime]] · [[Backend Runtime]] · [[Backend Char Programs]] · [[src/_MOC]]
