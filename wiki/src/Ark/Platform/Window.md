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
`FrameMismatch(expected, found)` or `Failed(message)`.

## Grill Log

- **Q:** Present through `Std.Ui` canvases? **A:** No; the engine already owns RGBA8 bytes and a
  canvas round trip would copy every frame twice. Present the bytes directly.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Platform Fixture]]
