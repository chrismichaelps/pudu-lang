---
type: module
path: "@root/src/Pudu/Backend/Runtime/Text/Pieces.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Text Pieces]
---
# Native Text Pieces

## Purpose and interface

Export textPieceRuntimeParts and textPieceRuntimeDependencies: the Str
methods that answer an array.

| Part | Provides |
| --- | --- |
| text_split | `pudu_text_split(text, separator)`, an `Array[Str]` |
| text_lines | `pudu_text_lines(text)`, an `Array[Str]` |
| text_chars | `pudu_text_chars(text)`, an `Array[Char]` |

## Semantics

They follow `callStringMethod`. `split` with an empty separator gives one
piece per character (`Text.chunksOf 1`), so empty text gives none; otherwise
the pieces are what lies between non-overlapping matches found left to right
(`Text.splitOn`), so empty text gives one empty piece. `lines` is `Text.lines`:
it breaks at `\n` only, a trailing newline ends the last line rather than
opening an empty one, and empty text gives nothing. `chars` decodes each
scalar.

## Resolved Grill Log

- **Q:** Copy each piece? **A:** No. A piece is a view of the receiver that
  retains its owner, as `Text` slices share their array, so splitting a large
  text allocates only the array.
- **Q:** Can a byte search split a character? **A:** No. Both texts are valid
  UTF-8, so a match of the separator's bytes starts and ends on character
  boundaries.
- **Q:** Why are these parts emitted after the frame types? **A:** They build
  arrays, which need `pudu_cell`, like the array runtime they sit beside.

## Dependencies and consumers

[[Backend Runtime Array]] · [[Native Text Methods]]

## Referenced by

[[Backend Frame Program]] · [[Native Runtime Dependencies]] · [[src/Pudu/Backend/_MOC]]
