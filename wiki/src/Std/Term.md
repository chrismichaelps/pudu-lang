---
type: module
path: "@root/lib/Std/Term.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, terminal, cli]
aliases: [Std Term]
---

# Std Term

## Purpose and interface

Terminal styling: ANSI select-graphic-rendition sequences, stripping them back out, and cursor
control for progress output.

Exports:
- `type Color = Named(Int) | Palette(Int) | Rgb(Int, Int, Int)`; constants `BLACK`, `RED`, `GREEN`,
  `YELLOW`, `BLUE`, `MAGENTA`, `CYAN`, `WHITE`, `GRAY`.
- `type Style = { foreground, background, bold, dim, italic, underline, inverse, strike }`.
- `plain() -> Style`; styles are built by record update: `Style{..Term.plain(), bold: true}`.
- `paint(text, style) -> Str`, `paintIf(enabled, text, style) -> Str`.
- `colorEnabled() -> Bool`: `FORCE_COLOR`, then `NO_COLOR`, then `TERM=dumb`.
- `strip(text) -> Str`, `visibleLength(text) -> Int`.
- `clearLine()`, `cursorUp(count)`, `hideCursor()`, `showCursor()`.

## Semantics

- Codes are written flags first (1, 2, 3, 4, 7, 9), then foreground, then background, in one
  sequence ending in a reset. A style that changes nothing writes `text` unchanged.
- Channel values are clamped to their range rather than refused: a colour is presentation, and a
  wrong channel is visible on screen rather than a data fault.

## Grill Log

- **Q:** Builder functions per attribute? **A:** No. _Rationale:_ record update already reads flat
  and names every field; a chain of `bold(red(text))` nests. _Rejected:_ wrapper combinators.
- **Q:** Decide colour inside `paint`? **A:** No. _Rationale:_ `paint` stays pure and testable;
  `colorEnabled` reads the environment once and `paintIf` takes the answer.

## Dependencies and consumers

- Depends on `Std.Env`.
- Consumed by command-line tools, test reporters, and progress output.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
