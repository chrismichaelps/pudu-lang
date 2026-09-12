---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Ui/Canvas.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, canvas, software-rendering]
aliases: [Std Ui Canvas]
---

# Std Ui Canvas

## Purpose and interface

A bounded, deterministic 2D software canvas written in Pudu. `Canvas` stores dimensions, an opaque
background, pixel and command budgets, and ordered rectangle commands. `render` produces an RGBA
`Surface`; `repaint` brings only damaged regions of an earlier surface up to date; `surfaceSize`,
`pixelAt`, and `rgbaBytes` validate its byte shape and inspect it without a device or window.

Public geometry is `Point`, `Size`, and `Rect`. `Color` uses four `UInt8` channels. `CanvasError`
distinguishes invalid dimensions, negative pixel or command budgets, a frame or display list
exceeding its budget, RGBA storage overflow, a non-opaque background, a rectangle or region with
negative extent, a malformed caller-constructed surface, or a surface whose size differs from the
canvas being repainted. Zero-area rectangles are accepted as no-ops.

## Governance and algorithm

Commands stay flat and execute in insertion order, matching a painter's model and allowing a future
backend to batch without walking a widget tree. Rectangle edges are half-open: the left/top pixel is
included and right/bottom is excluded. Clipping widens coordinates to `BigInt` before addition, then
clamps to the surface, so even `x + width` near the machine integer limit cannot overflow.

A surface produced by `render` is always opaque. An opaque fill replaces pixels. A translucent fill
uses integer source-over blending with round-to-nearest channel division; alpha zero changes nothing
and alpha 255 is identical to replacement. The byte order is RGBA, one pixel after another by rows.

Allocation is refused before machine-width narrowing when the BigInt `width * height` exceeds the
caller's pixel budget.
The defaults are 16,777,216 pixels (64 MiB of RGBA payload) and 65,536 commands. `canvasWithin`
changes the pixel bound; `canvasWithinLimits` makes both bounds explicit. Rendering revalidates the
exported record and every command, so direct record construction cannot bypass these refusals.

Rasterization works on bands and spans, never on individual pixels. Every command top and bottom is
a band edge, and rows between two consecutive edges are identical. Commands are swept by top edge;
the active list holds the commands covering the current band in display-list order, so painter
order is exact while commands above or below the band are not visited. Within a band a scanline is a
list of spans; a command splits the spans it overlaps and blends into each span once, and adjacent
spans of one color merge. The scanline's bytes are produced by doubling a four-byte pixel and the band
by doubling the scanline, so the pixel payload is made by whole-run copies.

`repaint` is the damage path: each region is clipped, rasterized alone, and spliced into the earlier
surface by carrying the untouched run between one replaced row and the next as a single slice. When
the regions cover every changed pixel, the result equals `render` byte for byte, which the fixture
checks directly.

Measured at -O2 on the development host, a program rendering a 512×512 frame with a full-frame
fill and a translucent 128×128 fill runs in 0.10 s, indistinguishable from one that renders
nothing, and holds 96 MB resident. Writing each pixel into an immutable buffer took 4.35 s and
267 MB for the same frame, because every write rebuilt the whole buffer.

## Referenced archive material

Apple's archived view-drawing guidance coalesces invalidated rectangles and draws only what
intersects them; `repaint` is that contract as a value: damage is data handed to the renderer, not a
flag set on a live object.

## Grill Log

- **Q:** Permit a transparent canvas background? **A:** Not in this slice. _Rationale:_ an opaque
  target gives source-over a fixed output representation and matches a presented desktop framebuffer.
  _Rejected:_ silently switching between straight and premultiplied alpha surfaces.
- **Q:** Panic on a negative rectangle? **A:** No. _Rationale:_ layout can derive rectangles from
  external dimensions; invalid extent is input, not an internal impossibility. _Rejected:_ partial
  drawing functions.
- **Q:** Clip with machine-width addition? **A:** No. _Rationale:_ clipping is where hostile extreme
  coordinates arrive, and overflow before the clamp defeats the clamp. _Rejected:_ `x + width` in
  `Int`.
- **Q:** Keep per-pixel blending as the translucent path? **A:** No. _Rationale:_ over an immutable
  buffer each write rebuilt the frame, and a span is one color, so blending once per span is exact.
  _Rejected:_ pixel-at-a-time writes, and a hidden runtime primitive to make them cheap.
- **Q:** Track damage inside the canvas? **A:** No. _Rationale:_ the layout layer knows which frames
  changed; the canvas takes regions explicitly so a caller can test the equality with `render`.
  _Rejected:_ implicit dirty flags on a canvas value.
- **Q:** Add a window API now? **A:** No. _Rationale:_ this module owns pixels, not a platform device,
  and the user prohibited foreign UI integration. _Rejected:_ a no-op or hidden foreign presenter.

Resolved Grill Log: the surface is bounded and opaque, geometry cannot overflow while clipping,
every fallible constructor/draw operation returns a typed error, and rendering is fully headless.

## Referenced by

Depends on [[Std Buffer]], [[Std Bytes]], [[Std List]], `Std.Num.Integer`, and [[Std Option]].

Consumed by [[Uses Ui Canvas]] and [[Service Evaluation Spec]].

[[src/Std/_MOC]] · [[Native Application UI]] · [[2026-09-12-release-readiness-ui]]
