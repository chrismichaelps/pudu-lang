---
type: module
path: "@root/lib/Std/Ui/Theme.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, theme, accessibility]
aliases: [Std Ui Theme]
---

# Std Ui Theme

## Purpose and interface

Design tokens for desktop views: colors by role, spacing, corner radius, and a type scale, with
light and dark appearances and WCAG contrast arithmetic.

Exports:
- `type Mode = Light | Dark`, `type Palette` (background, surface, text, mutedText, accent,
  onAccent, border, danger, success, focus), `type TypeScale`, `type Theme`.
- `light()`, `dark()`, `forMode(mode)`, `withAccent(theme, color)`, `space(theme, steps)`.
- `luminance(color)`, `contrast(a, b)`, `meetsContrast(fg, bg, large)`, `readableOn(bg)`,
  `mix(a, b, percent)`, `contrastFailures(theme)`.

## Semantics

- A view reads `theme.palette.danger`, never a literal color, so switching appearance is passing a
  different `Theme` value to the same view function.
- `withAccent` recomputes `onAccent`, so a brand color never produces unreadable button text.
- `contrastFailures` audits the text pairings against level AA; both shipped themes pass it, which
  the fixture asserts.

## Grill Log

- **Q:** Hold the theme in an ambient environment? **A:** No. _Rationale:_ there is no ambient
  mutable state; the theme is part of the screen's state or an argument to its view, so a preview
  of both appearances is two calls. _Rejected:_ a global current theme.
- **Q:** Why compute contrast rather than trust the palette? **A:** Accents are user data; a
  computed check is the only one that covers a color nobody reviewed.

## Dependencies and consumers

- Depends on [[Std Ui Canvas]], [[Std Math Float]], `Std.Num`.
- Consumed by application views and [[Std Ui Screen]] backgrounds and focus rings.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
