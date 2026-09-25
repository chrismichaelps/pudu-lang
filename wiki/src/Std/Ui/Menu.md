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
`command`, `commandsOf`, `problems`, `view`, `opened`, `commandOf`.

## Semantics

- Menu titles are tagged `menu.<title>` and commands `command.<name>`; `opened` toggles a menu and
  closes it on a command or `Dismissed`, and `commandOf` names the command an event ran.
- A command is read aloud with its shortcut label (`Save, ⌘S`), so the shortcut is discoverable
  without sight.
- `problems` reports empty menus, commands listed twice, and bound shortcuts whose command no menu
  offers — a command reachable only by a chord nobody can discover.

## Grill Log

- **Q:** Drive the platform's native menu bar? **A:** Not yet: that needs adapter support and is
  recorded as absent in [[architecture/NATIVE-UI]]. The data model is the one a native presenter
  will read, so programs do not change when it arrives.
- **Q:** Why commands by name rather than closures? **A:** The same names flow from menus,
  shortcuts, and command palettes into one `apply` function.

## Dependencies and consumers

- Depends on [[Std Ui Controls]], [[Std Ui Keymap]], [[Std Ui Layout]], [[Std Ui Screen]],
  [[Std Ui Theme]].
- Consumed by desktop applications.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
