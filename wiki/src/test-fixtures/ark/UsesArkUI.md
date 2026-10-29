---
type: module
path: "@root/test-fixtures/ark/UsesArkUI.pudu"
fidelity: Active
aliases: [Ark UI Fixture]
tags: [module, ark, ui, test]
---

# Ark UI Fixture

## Purpose and interface

Drives a settings panel (label, button, checkbox, slider) with recorded input: declaration order,
press-to-arm and focus, release-to-click, a release elsewhere not clicking, checkbox toggling,
slider grab, drag and clamp; Tab, Enter, arrow keys, wrap-around and Shift-Tab. Renders the panel
and checks exact pixel colors for the idle button, the checked box, the full slider and an
untouched background, an empty draw list and half-open hit testing. Prints `ark ui: ok`.

## Resolved Grill Log

- **Q:** Test interaction with synthetic state records? **A:** No; input flows through
  `Input.apply` and `beginFrame`, exactly as the window adapter feeds it.

## Referenced by

[[Ark UI]] · [[Ark UI Gate]] · [[src/Ark/_MOC]]
