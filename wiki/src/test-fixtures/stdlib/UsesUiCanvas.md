---
type: module
path: "@root/test-fixtures/stdlib/UsesUiCanvas.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, ui, canvas]
aliases: [Uses Ui Canvas]
---

# Uses Ui Canvas

## Purpose and interface

Executable Pudu fixture for the native software canvas. Its `main` returns 33 held assertions for
valid construction, pixel/command/storage bounds, surface-shape validation, clipping on every edge,
painter order, byte order, opaque replacement, repeated translucent blending, transparent no-op
behavior, zero-area rectangles, and invalid geometry.

## Grill Log

- **Q:** Compare only rendered byte length? **A:** No. _Rationale:_ the wrong channel order or blend
  can have the right length. _Rejected:_ shape-only framebuffer tests.
- **Q:** Skip extreme coordinates because ordinary windows are small? **A:** No. _Rationale:_ the
  clipping contract exists precisely at untrusted geometry boundaries. _Rejected:_ testing only
  comfortably representable sums.

Resolved Grill Log: exact pixels and typed refusals cover success, failure, regression, and boundary
behavior without opening a host window.

## Referenced by

[[Std Ui Canvas]] · [[Service Evaluation Spec]]
