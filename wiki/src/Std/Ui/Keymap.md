---
type: module
path: "@root/lib/Std/Ui/Keymap.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, keyboard, commands]
aliases: [Std Ui Keymap]
---

# Std Ui Keymap

## Purpose and interface

Keyboard shortcuts as a table from chords to named commands, resolved per platform and labelled the
way each platform's menus show them.

Exports:
- `type Binding = { chord, command, title }`, `type Keymap`, `type KeymapError`.
- `keymap()` and the `Binds` chain `.bind(chord, command, title)`.
- `normalize(chord)`: lower case, aliases (`command`, `option`, …) resolved, modifiers ordered
  mod, cmd, ctrl, alt, shift — the order the desktop adapter writes chords in.
- `forPlatform(keymap, apple)`: `mod` becomes `cmd` or `ctrl`.
- `commandFor`, `chordsFor`, `problems` (malformed chords, one chord bound to two commands).
- `label(chord, apple)`: `⌘⇧Z` or `Ctrl+Shift+Z`.
- `handler(keymap, apply)`: the `onShortcut` argument of `Desktop.drive`.
- `explain`.

## Grill Log

- **Q:** Bind closures to chords? **A:** No. _Rationale:_ a command name is data a menu, a command
  palette, and a test can all list; the one `apply` function is where commands change state.
  _Rejected:_ a map of chords to closures.
- **Q:** Refuse conflicting bindings at `bind`? **A:** No; `problems` reports them all at once, so
  a keymap built from user settings can be shown with every issue rather than failing on the first.

## Dependencies and consumers

- No dependencies.
- Consumed by [[Std Ui Desktop]] `drive` and application menus.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
