---
type: module
path: "@root/test/native/DesktopPresentation.m"
fidelity: Active
aliases: [Desktop Presentation Test]
tags: [module, test, desktop, macos]
---
# Desktop Presentation Test

Draw the actual PuduFrameView through an unflipped NSGraphicsContext into an owned RGBA bitmap.
An asymmetric2x3 opaque surface gives each corner/row distinct colors. Require exact channels and
row order with logical extent2x3, resized4x6 bounds and a2x device transform, and opaque black
when no frame exists. Restore the previous graphics context and release owned buffers/context.
No window server interaction or screen capture is needed for this deterministic test.

## Resolved Grill Log

- **Q:** Test a copied transform? **A:** No; link and invoke the real native adapter/view.
- **Q:** Use a symmetric image? **A:** No; distinct rows and columns expose reversal/channel errors.
- **Q:** Require a Haskell compiler build? **A:** No; a small Objective-C executable checks this boundary.

## Referenced by

[[Pudu Desktop Adapter]] · [[Desktop Presentation Gate]] · [[Desktop Presentation Delivery]]
