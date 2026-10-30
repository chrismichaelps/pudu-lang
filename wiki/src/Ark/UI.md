---
type: module
path: "@root/lib/Ark/UI.pudu"
fidelity: Active
aliases: [Ark UI]
tags: [module, ark, ui]
---

# Ark UI

## Purpose and interface

Immediate-mode widgets over [[Ark Input]]. `begin(memory, input, x, y, width, rowHeight)` starts a
frame with a top-down column cursor; `next` hands out row rectangles. `label`, `button(ui, id,
text) -> (Ui, Bool)`, `checkbox(ui, id, text, checked) -> (Ui, Bool)` and `slider(ui, id, value,
low, high) -> (Ui, Float64)` declare widgets; `end` answers the `Memory` for the next frame and the
draw list of `Fill` and `Text` commands. `render(commands, target, font)` draws every fill as two
screen-space triangles in one [[Ark Render Device]] call, with depth assigned so later commands
sit on top, then every text command in one [[Ark Text]] batch above all fills: inset four pixels,
at the largest whole scale whose glyphs fit the row with two pixels to spare, centred vertically. `contains` is the half-open hit test.

`Memory` carries the widget holding the primary press, the keyboard focus and the focusable ids
in last frame's declaration order. A press over a widget makes it active and focused; a release
over the widget that held the press is a click. Tab and Shift-Tab move focus through the declared
order with wrap-around; Enter activates a focused button or checkbox; arrow keys step a focused
slider by a twentieth of its range. Colors come from a const palette keyed by widget state.

## Invariants

- A click needs both press and release over the same widget.
- Widgets below in declaration order draw over earlier ones; untouched pixels keep their color.
- Text runs are recorded with their rectangles for a font renderer; glyph rasterization is open.

## Resolved Grill Log

- **Q:** Keep a retained widget tree? **A:** No; immediate-mode declarations rebuild each frame,
  and only interaction memory persists, so game state stays the single source of truth.
- **Q:** Draw each rectangle with its own device call? **A:** No; all fills form one batch, so a
  panel costs one native call.

## Referenced by

[[src/Ark/_MOC]] · [[Ark UI Fixture]] · [[Ark UI Gate]]
