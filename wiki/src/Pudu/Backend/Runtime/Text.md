---
type: module
path: "@root/src/Pudu/Backend/Runtime/Text.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Text Runtime]
---
# Native Text Runtime

## Purpose and interface

Export textRuntimeParts :: [(Text, [Text])] and textRuntimeDependencies ::
Text -> [Text], published through [[Backend Runtime]] and
[[Native Runtime Dependencies]].

`pudu_text` is `{const unsigned char *bytes; size_t length; pudu_text_owner *owner;}`.
An owner is `{size_t count; unsigned char bytes[];}`. Parts:

| Part | Provides |
| --- | --- |
| text | the two types and `pudu_text_release` |
| text_retain | `pudu_text_retain`, selected with the frame engine for any program with text |
| text_literal | `pudu_text_literal(bytes, length)` over static bytes |
| text_allocate | `pudu_text_allocate(length, &bytes)`, the one allocation path |
| text_copy | `pudu_text_copy(bytes, length)` for rendered scratch buffers |
| text_concat | `pudu_text_concat(left, right)`; an empty side retains the other |
| text_compare | `pudu_text_compare(left, right)` as -1/0/1 by bytes, then length |
| text_show | `pudu_text_show(text)`: quotes plus the `\\` `\"` `\t` `\n` escapes |
| text_display_int / text_display_wide / text_display_float | decimal or locked GHC float text |
| print_text | bytes, newline, one flush |

Every function returning `pudu_text` returns a reference the caller owns;
arguments are borrowed. Size arithmetic is checked before allocating, and an
allocation failure is `pudu_memory_failure`, the interpreter's message.

## Negative logic

No NUL-terminated strings: lengths are explicit, so `\0` survives. No libc
locale or formatting for floats (the #509 formatter writes the bytes). No
interning or sharing that could make two values alias mutable state; text is
never mutated after it is filled.

## Grill Log

- **Q:** Why a view instead of a pointer to one block? **A:** Literals need no
  allocation, and the coming `drop`/`take`/`slice` must share their source the
  way Data.Text slices do, keeping the cost of a scan proportional to what it
  moves. _Rejected:_ copying on every slice.
- **Q:** Why plain counts instead of atomics? **A:** Native programs are single
  threaded until tasks are admitted; that slice must revisit this.
- **Q:** Why does `print_text` ignore write errors? **A:** Same continuation
  contract as the other printers; the Result side of print is not
  represented yet.

## Dependencies and consumers

[[Backend Runtime]] · [[Native Runtime Dependencies]] · [[Native Binary64 Formatter]] · [[Backend Frame Values]]

## Referenced by

[[src/_MOC]] · [[src/Pudu/Backend/_MOC]] · [[Native Emission Coverage]]
