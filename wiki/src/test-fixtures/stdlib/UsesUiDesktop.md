---
type: module
path: "@root/test-fixtures/stdlib/UsesUiDesktop.pudu"
fidelity: Active
tags: [module, fixture, ui, desktop]
aliases: [Uses Ui Desktop]
---

# Uses Ui Desktop

## Purpose

Exercise the Pudu-owned desktop contract with a small, visibly identifiable Canvas surface. The
ordinary fixture path checks validation without opening a device. A launch entry opens a real
desktop window, presents the exact surface, pumps the event loop for a bounded interval, and closes
it, returning a stable success value for the manual macOS launch gate.

## Grill Log

- **Q:** Count a PNG or framebuffer as launch evidence? **A:** No. _Rationale:_ the release
  requirement specifically asks that desktop applications actually launch. _Rejected:_ headless
  evidence as a substitute.
- **Q:** Put a GUI launch into every CI run? **A:** No. _Rationale:_ build agents may have no window
  server. _Accepted:_ pure validation in the standard suite plus an explicit macOS launch gate that
  fails when a real session cannot open.

## Referenced by

[[Std Ui Desktop]] · [[Eval Service Spec]]
