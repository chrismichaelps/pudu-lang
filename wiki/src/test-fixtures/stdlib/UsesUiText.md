---
type: module
path: "@root/test-fixtures/stdlib/UsesUiText.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, ui, text]
aliases: [Uses Ui Text]
---

# Uses Ui Text

## Purpose and interface

Executable Pudu fixture for bitmap text. Its `main` returns 22 held assertions. Drawing "I" within a
one-row window keeps only the top bar's rectangle.

Faces and measures: scales below one and above sixty-four are refused; metrics, empty text, a single
glyph without trailing space, several glyphs, and multi-line text with a trailing newline measure
exactly; the glyph table covers space through tilde and excludes tab and non-ASCII characters.

Wrapping: greedy word placement at two widths, hard breaks inside a word wider than a line, one
character per line at zero width, empty lines from consecutive newlines, a negative width refused, and
at scale three the exact width at which two words first share a line.

Drawing: "I" becomes exactly three rectangles with its stem joined across rows; stacked bars leave the
leading gap between lines; a character outside the table draws the hollow box; spaces draw nothing;
text starting above and left of the canvas clips; a command budget too small for one glyph is refused
with the canvas error carried; and a scale-three hyphen covers exactly its scaled cell.

## Grill Log

- **Q:** Assert only command counts? **A:** No. _Rationale:_ the right number of rectangles can sit in
  the wrong place. _Rejected:_ count-only drawing checks; pixels inside and just outside each edge are
  checked.

## Referenced by

[[Std Ui Text]] · [[Service Evaluation Spec]]
