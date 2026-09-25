---
type: module
path: "@root/lib/Std/Ui/Menu.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, menus, commands]
aliases: [Std Ui Menu]
---

# Std Ui Menu

## Purpose and interface

A menu bar as data: menus of commands, separators, and submenus, drawn in the window with each
command's shortcut from [[Std Ui Keymap]], and checked against that keymap.

Exports: `type Item = Command(title, name) | Separator | Submenu(Menu)`, `type Menu`, `menu`,
`command`, `commandsOf`, `problems`, `view`, `opened`, `commandOf`, `native`.

`native(bar, keys)` writes the bar as the records the desktop adapter builds the platform's menu bar
from, one per line, depth first: `menu`, depth, title; `command`, depth, name, chord, title; and
`separator`, depth. A top-level menu is at depth 0 and its items at depth 1; a submenu at depth `d`
holds items at `d + 1`. The chord is the command's first binding with `mod` resolved to `cmd`, or
empty. Tabs and line breaks in titles become spaces.

## Semantics

- Menu titles are tagged `menu.<title>` and commands `command.<name>`; `opened` toggles a menu and
  closes it on a command or `Dismissed`, and `commandOf` names the command an event ran.
- A command is read aloud with its shortcut label (`Save, ⌘S`), so the shortcut is discoverable
  without sight.
- `problems` reports empty menus, commands listed twice, and bound shortcuts whose command no menu
  offers — a command reachable only by a chord nobody can discover.

## Grill Log

- **Q:** Drive the platform's native menu bar? **A:** Yes, through `native` and
  [[Std Ui Desktop]] `install`. _Rationale:_ the data model is the one the native presenter reads,
  so a program that drew its bar in the window installs the same value. _Rejected:_ a second,
  native-only menu type.
- **Q:** Resolve `mod` in `native` rather than asking the caller? **A:** Yes. _Rationale:_ the only
  native menu bar is Apple's, where `mod` is always Command.
- **Q:** Why commands by name rather than closures? **A:** The same names flow from menus,
  shortcuts, and command palettes into one `apply` function.

## Dependencies and consumers

- Depends on [[Std Ui Controls]], [[Std Ui Keymap]], [[Std Ui Layout]], [[Std Ui Screen]],
  [[Std Ui Theme]].
- Consumed by desktop applications and [[Std Ui Desktop]] `install`.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]] · [[Std Ui Desktop]] · [[Pudu Desktop Menu]] · [[Uses Ui Menu Bar]]
