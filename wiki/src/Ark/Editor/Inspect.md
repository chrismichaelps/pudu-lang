---
type: module
path: "@root/lib/Ark/Editor/Inspect.pudu"
fidelity: Active
aliases: [Ark Inspect]
tags: [module, ark, editor, derive]
---
# Ark Inspect

## Purpose and interface

Property inspectors generated from Pudu types. A record writes `derives Inspect.Inspect` and gets
`properties(value, path, hint) -> Array[Property]` and `change(value, segments, text, hint) ->
Result[T, EditError]` without writing either. `rows(value)` lists every property from the root,
and `edit(value, path, text)` changes the one at a dotted path (`"body.position.x"`, with `[i]` for
an array element).

A `Property` has its `path`, `label`, `kind` (`Number`, `Whole`, `Toggle`, `Words` or `Group`), its
value as `text`, a range (`ranged`, `low`, `high`) and `editable`. A field's attributes form the
`Hint` its value receives: `@label("Max speed")` replaces the field name, `@min(…)` with `@max(…)`
gives a range, `@readonly` makes it display-only and `@skip` hides it. Leaf implementations cover
`Float64`, `Int`, `Bool`, `Str`, Ark's `Vec3` (a group of `x`, `y`, `z`) and `Array` (a group of
`[i]` children); nested records are groups of their fields.

Edits parse the text for the leaf's kind and refuse, naming the path: `UnknownField(name)`,
`NotEditable`, `Unparsable(expected)` (also for non-finite numbers), `OutOfRange(low, high)` and
`NotALeaf` for a path that stops at a group or goes past a leaf.

`panel(ui, value) -> (Ui, T)` draws the rows with [[Ark UI]]: a slider for a ranged editable number,
a checkbox for an editable flag, and a label (`label: text`) for everything else, indented by
depth. A widget the person changed edits the value through `edit`, so the panel answers the value
after this frame's interaction.

## Grill Log

- **Q:** Hand-write inspectors per engine type? **A:** No; the editor must follow a type's fields
  as they change. The derive reads them at compile time, so an inspector is never stale.
- **Q:** Let leaf types read field attributes? **A:** They cannot see the field; the derive turns
  attributes into a `Hint` passed down, so ranges and labels apply to any field type.
- **Q:** Edit through the panel's widgets only? **A:** No; `edit(value, path, text)` is the single
  edit path, which consoles, undo stacks and the panel share.

## Referenced by

[[src/Ark/_MOC]] · [[Ark UI]] · [[Ark Inspect Fixture]]
