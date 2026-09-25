---
type: module
path: "@root/lib/Std/Ui/Draw.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, drawing]
aliases: [Std Ui Draw]
---

# Std Ui Draw

## Purpose and interface

Strokes over [[Std Ui Canvas]]: `line(canvas, from, to, width, color)` with round ends,
`polyline(canvas, points, width, color)`, `outline(canvas, area, width, color)`,
`linearGradient(canvas, area, from, to, horizontal)`, `polygon(canvas, points, color)`, `explain`, and
`type DrawError = InvalidWidth(Int) | TooFewPoints(Int) | Painting(CanvasError)`.

## Semantics

- A pixel is painted when its centre lies within half the stroke width of the segment. Coordinates
  are doubled so centres are integers, and the distance test is exact integer arithmetic, so the same
  stroke paints the same pixels on every machine.
- A thick segment is convex, so each covered row is one span and becomes one canvas fill; the
  canvas's band-and-span rasterizer does the rest.
- `outline` strokes inward, so an outlined control keeps its frame.
- A gradient's first line is exactly `from` and its last exactly `to`; lines between blend in whole
  percent through `Theme.mix`, one fill each.
- A polygon fills by the even-odd rule. Edge crossings on doubled coordinates are rounded up, which
  decides every odd pixel centre against a rational crossing exactly on both sides of a span; the
  fixture caught the floor-rounded first version admitting a pixel just outside a concave edge.

## Grill Log

- **Q:** Add a line command to the canvas itself? **A:** Not yet. _Rationale:_ spans over existing
  fills reuse the exact painter and its fixtures without widening the command set; a native line
  command is worth adding when measurements show span count matters. _Rejected:_ floating-point
  antialiased lines, whose pixels vary with rounding.

## Dependencies and consumers

- Depends on [[Std Ui Canvas]].
- Consumed by charts, separators, focus outlines, and custom controls.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
