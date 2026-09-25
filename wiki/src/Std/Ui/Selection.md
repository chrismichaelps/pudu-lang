---
type: module
path: "@root/lib/Std/Ui/Selection.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, lists, selection]
aliases: [Std Ui Selection]
---

# Std Ui Selection

## Purpose and interface

Which rows of a list are chosen, with the anchor a range extends from and the focus keyboard movement
starts from.

Exports: `type Selection`, `selection(count)`, `single`, `toggle`, `extend`, `all`, `clear`,
`move(selection, delta, extending)`, `resized`, `isSelected`, `selected`, `activated(selection,
event, prefix)`, `commanded(selection, command)` for `select.all`, `select.none`, `select.next`,
`select.previous`, `select.extendNext`, `select.extendPrevious`.

## Semantics

- `single` resets the anchor; `extend` keeps it and chooses every row between it and the target, in
  either direction; `toggle` adds or removes one row and moves the anchor there.
- Movement clamps to the list; from no focus, moving forward starts at the first row and backward at
  the last.
- `resized` drops rows past a shrunken list and clears an anchor or focus that fell off the end, so a
  deleted row can never stay selected.

## Grill Log

- **Q:** Keep selection inside the list view? **A:** No. _Rationale:_ selection drives toolbars, menus,
  and commands elsewhere in the window; as state it is visible to all of them and to undo.
  _Rejected:_ a list control owning its selection.
- **Q:** Why commands rather than keys? **A:** Chords belong to [[Std Ui Keymap]]; the same command
  names come from menus, so every way of selecting passes through `commanded`.

## Dependencies and consumers

- Depends on [[Std Ui Screen]].
- Consumed with [[Std Ui Virtual]] by list and table views.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
