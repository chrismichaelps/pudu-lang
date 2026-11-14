---
type: module
path: "@root/test-fixtures/ark/UsesArkText.pudu"
fidelity: Active
aliases: [Ark Text Fixture]
tags: [module, ark, test, render, text]
---
# Ark Text Fixture

Draws text through [[Ark Text]] and compares every pixel with the glyph bits [[Std Ui Text]]
exports: at scales one and two each design pixel covers its square of target pixels exactly,
lit pixels take the batch color and the rest keep the background. A newline starts nine units
lower, a space adds no glyph, a character outside printable ASCII draws the missing-glyph box,
several strings share one draw, an empty batch leaves the target unchanged, and `measure` and
`wrap` agree with `Std.Ui.Text`. Refusals: scales 0 and 65 and text past the character limit.
Prints `ark text: ok`.

## Referenced by

[[Ark UI Gate]] · [[Ark Text]]
