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
`Surface`; `surfaceSize`, `pixelAt`, and `rgbaBytes` validate its byte shape and inspect it without a
device or window.

Public geometry is `Point`, `Size`, and `Rect`. `Color` uses four `UInt8` channels. `CanvasError`
distinguishes invalid dimensions, negative pixel or command budgets, a frame or display list
exceeding its budget, RGBA storage overflow, a non-opaque background, a rectangle with negative
extent, a malformed caller-constructed surface, or an internal rendering failure. Zero-area
rectangles are accepted as no-ops.

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

Background construction expands one four-byte pixel pattern in Pudu instead of replacing an
immutable buffer once per pixel. Opaque rectangles build one scanline and copy it per affected row;
translucent rectangles retain the exact per-pixel blend path.

This is the conformance renderer, not yet a real-time presenter. An exploratory optimized-interpreter
run of a 512×512 opaque frame took about 2.6 seconds on the development host, far outside an
interactive frame budget. No next-generation performance claim is permitted until a repeatable
benchmark gate drives that gap down without changing the exact-pixel oracle.

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
- **Q:** Add a window API now? **A:** No. _Rationale:_ this module owns pixels, not a platform device,
  and the user prohibited foreign UI integration. _Rejected:_ a no-op or hidden foreign presenter.

Resolved Grill Log: the surface is bounded and opaque, geometry cannot overflow while clipping,
every fallible constructor/draw operation returns a typed error, and rendering is fully headless.

## Referenced by

Depends on [[Std Buffer]], [[Std Bytes]], `Std.Num.Integer`, and [[Std Option]].

Consumed by [[Uses Ui Canvas]] and [[Service Evaluation Spec]].

[[src/Std/_MOC]] · [[Native Application UI]] · [[2026-09-12-release-readiness-ui]]
