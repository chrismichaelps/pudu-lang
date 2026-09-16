---
type: module
path: "@root/test-fixtures/stdlib/LaunchUiDesktop.pudu"
fidelity: Active
tags: [module, fixture, ui, desktop, launch]
aliases: [Launch Ui Desktop]
---

# Launch Ui Desktop

## Purpose

Launch the real macOS desktop presenter with a bounded, visibly identifiable Pudu-rendered surface.
Success means a platform session opened, copied and displayed the exact Canvas bytes, pumped the
event loop, and closed normally. This fixture is run explicitly on a machine with a display server.

## Grill Log

- **Q:** Leave the window open until manual interaction? **A:** No. _Rationale:_ acceptance testing
  must terminate predictably. _Accepted:_ a bounded visible interval during which manual close is
  also a successful lifecycle event.
- **Q:** Render platform text for the proof? **A:** No. _Rationale:_ that would bypass Pudu's renderer.
  _Accepted:_ a distinctive composition rendered entirely by `Std.Ui.Canvas`.

## Referenced by

[[Uses Ui Desktop]] · [[Native Application UI]]
