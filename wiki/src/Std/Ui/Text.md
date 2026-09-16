---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Ui/Text.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, text, glyphs]
aliases: [Std Ui Text]
---

# Std Ui Text

## Purpose and interface

Text for application screens with no font file and no foreign rasterizer. `face` makes a `Face` at a
whole-number scale from 1 to 64; `metrics` gives its advance, ascent, and line height in pixels;
`hasGlyph` says whether a character has its own glyph; `measure` sizes text with newlines; `wrapped`
breaks text into lines no wider than a width; and `draw` adds the text to a [[Std Ui Canvas]] as fill
commands. `TextError` distinguishes an invalid scale, a negative width, text beyond the character
bound, and a drawing refusal carried from the canvas.

## Governance and algorithm

**An original face in a constant table.** Every printable ASCII glyph from space to tilde was drawn
for Pudu on a five-column, seven-row grid and is packed into one `UInt64` per glyph, top row and left
column in the highest bits, in a module constant indexed by character code. Any other character draws
a hollow box, so missing coverage is visible rather than silent. No glyph shapes, metrics, or data
come from another font.

**Design units scaled by whole numbers.** A glyph is five units wide with one unit of space after it,
and lines are nine units apart: seven for the glyph and two of leading. Scaling by an integer keeps
every edge on a pixel boundary, so text shares the exactness of every other canvas command. Measured
width omits the space after a line's last glyph.

**Wrapping is greedy and always progresses.** Newlines always break. Words separated by spaces are
placed while they fit; the space at a break is dropped; a word wider than the line breaks between
characters; and at least one character is placed per line, so even a zero width terminates.

**Drawing emits the fewest rectangles a bitmap allows.** Lit columns in a row join into a run, and a
run whose exact extent repeats in the rows below extends downward into one taller rectangle, so a
stem is one command rather than seven. The letter "I" is three rectangles. Fewer commands mean fewer
band edges and spans in the canvas rasterizer.

**Drawing can be cut to a window.** `drawWithin` draws as `draw` does with every glyph rectangle
intersected with a window first; rectangles wholly outside it add no command, so text scrolled out of
view costs nothing to render.

**Bounded input.** Each call admits at most 1,048,576 characters; the canvas command budget bounds
what a draw may add, and exceeding it is reported with the canvas's own error.

## Measured

At -O2 on the development host, 40 repetitions of "Pudu text " (400 characters) at scale 2, wrapped to
780 pixels as seven lines, become 1,072 rectangles. Measuring, wrapping, and drawing take 0.36 s
including process startup; rendering the 800×200 canvas brings the total to 1.40 s median, 99 MB
resident. Rendering many small rectangles is the rasterizer's remaining hot path and the next
performance item; it is not an interactive frame budget yet.

## Referenced archive material

The archived Core Text overview describes lines built from runs of consistently styled glyphs placed
by ascent, leading, and advances. This module keeps that vocabulary as plain values—advance, ascent,
line height—at bitmap scale, and leaves shaping, bidirectional runs, and outline fonts to later slices
that must meet the same exact-pixel fixtures.

## Grill Log

- **Q:** Parse TrueType files first? **A:** Not in this slice. _Rationale:_ an outline rasterizer and
  font parser are large and bring font licensing into the standard library; screens need legible
  labels now. _Rejected:_ bundling a third-party font. Revisit with an outline-coverage renderer.
- **Q:** Emit one rectangle per lit pixel? **A:** No. _Rationale:_ it multiplies commands and band
  edges. _Rejected:_ per-pixel commands; runs extend across rows.
- **Q:** Skip characters without glyphs? **A:** No. _Rationale:_ silently dropped text hides data loss.
  _Rejected:_ blank output; a hollow box is drawn.
- **Q:** Allow fractional scale? **A:** No. _Rationale:_ fractional edges need coverage blending and
  would break exact-pixel equality with the layout grid. _Rejected:_ floating scale in this face.

Resolved Grill Log: an original bitmap face with integer metrics, progressive wrapping, merged glyph
rectangles, visible missing glyphs, and bounded input.

## Referenced by

Depends on [[Std Ui Canvas]] and [[Std Option]].

Consumed by [[Uses Ui Text]] and [[Service Evaluation Spec]].

[[src/Std/_MOC]] · [[Native Application UI]] · [[2026-09-12-release-readiness-ui]]
