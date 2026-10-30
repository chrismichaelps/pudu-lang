---
type: module
path: "@root/lib/Ark/Render/Text.pudu"
fidelity: Active
aliases: [Ark Text]
tags: [module, ark, render, text]
---
# Ark Text

## Purpose and interface

Bitmap text for HUDs, menus and debug overlays. `font()` is the [[Std Ui Text]] five-by-seven
face as a glyph atlas: a 96 by 48 RGBA8 texture of sixteen columns and six rows of six-by-eight
cells, glyphs white and opaque, everything else transparent. The atlas bytes are a module
constant computed by a compile-time function from `Std.Ui.Text.GLYPHS`, so a running program
never builds it and the two renderers share one copy of the face.

A `Batch` collects text: `add(batch, text, x, y, scale, color) -> Result[Batch, TextError]` lays a
string out from its top-left corner at a whole-number scale, each character advancing six units
and each newline starting a line nine units lower, with a space taking no quad and a character
outside printable ASCII drawn as the missing-glyph box. `draw(target, font, batch, depth)` draws
every glyph of the batch in one textured [[Ark Render Device]] call: the vertex color tints the
white atlas and transparent texels are cut out, so the text keeps its own color over whatever is
behind it. `measure` and `wrap` delegate to `Std.Ui.Text`, so layout and measurement agree.

The interpreted work per character is recording its origin, glyph index, scale and color. The six
vertices per glyph, their corner offsets and atlas coordinates come from lane kernels (`ramp`,
`floor`, `gather`, `axpy`) over the whole batch at once.

`TextError` is `Std.Ui.Text.TextError`: an invalid scale (outside 1 to 64) or text past the
character limit.

## Measurement

[[Ark Text Benchmark]] at -O2: a 640 by 480 screen of 40 lines of 80 characters lays out in about
21 ms and draws in about 19 ms. Layout is the interpreted per-character pass, about 7
microseconds a character, so a 200-character HUD lays out in about 1.3 ms. Text that does not
change each frame should be laid out into a batch once and drawn from it every frame.

## Grill Log

- **Q:** Draw glyphs as filled rectangles like `Std.Ui.Text`? **A:** No; a stem per rectangle is
  several triangles per glyph and one device call per rectangle batch. One textured quad per
  glyph through one call per batch is two triangles a glyph.
- **Q:** Copy the glyph table into Ark? **A:** No; `Std.Ui.Text` exports it, so desktop
  applications and the engine draw the same face from one source.
- **Q:** Build the atlas when a font is requested? **A:** No; a compile-time constant costs
  nothing at run time, and a running loop never pays for 18,432 bytes of texels.
- **Q:** Sample the atlas with a bilinear filter? **A:** No; nearest sampling at whole-number
  scales keeps every glyph edge on a pixel, and cut-out alpha needs exact texels.

## Referenced by

[[src/Ark/_MOC]] · [[Ark UI]] · [[Ark Text Fixture]] · [[Ark Text Benchmark]]
