---
type: module
path: "@root/lib/Ark/Platform/Window.pudu"
fidelity: Active
aliases: [Ark Window]
tags: [module, ark, platform]
---
# Ark Window

## Purpose and interface

The engine's only window boundary, over the runtime desktop adapter. `open(title, width, height,
resizable) -> Result[Window, PlatformError]`, `present(window, rgba)` (refuses a frame whose
byte count is not width × height × 4), `pump(window, millis) -> Result[Bool]` (true when close
was requested), `events(window) -> Result[Array[Input.Event]]`, `resized(window, width,
height)` and `close`. `PlatformError` is `Unsupported`, `Closed`, `InvalidSize`,
`FrameMismatch(expected, found)`, `InvalidDensity`, `InvalidLimits`, `InvalidAspect` or
`Failed(message)`.

A `Window` holds its frame size in pixels (`width`, `height`), its content size in points
(`logicalWidth`, `logicalHeight`), the backing `scale` in thousandths, `focused`, `minimized`
and `fullscreen` state and the `Settings` last applied. `Settings` is a flat record: `sharp`
(render at backing resolution), content `minWidth`/`minHeight`/`maxWidth`/`maxHeight` in points
(zero is unlimited), `aspectWidth`/`aspectHeight` (zero is none) and `fullscreen`; `windowed()`
is sharp off, no limits, windowed. `configure(window, settings)` applies settings through the
runtime, which is the single validator; its messages map through a const table to the typed
refusals. `observe(window, events)` folds the frame's events into the window: a resize sets the
content size, a rescale sets the scale and, when sharp, re-applies the density so frames stay at
backing resolution, and focus, minimize and full-screen events set their flags. The frame size
is `pixels(points, scale)`: points times scale over one thousand, rounded up, so a fractional
scale never produces a frame smaller than its content.

## Grill Log

- **Q:** Present through `Std.Ui` canvases? **A:** No; the engine already owns RGBA8 bytes and a
  canvas round trip would copy every frame twice. Present the bytes directly.

- **Q:** Render sharp by default? **A:** No; the software device draws every pixel, so a 2x
  display costs four times the work. Games opt in with `sharp`, and the window still knows its
  scale either way.
- **Q:** Validate settings in Pudu as well? **A:** No; one rule set lives in the runtime, which
  already refuses before touching the window, and a const table types its messages.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Platform Fixture]]
