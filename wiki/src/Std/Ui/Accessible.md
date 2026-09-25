---
type: module
path: "@root/lib/Std/Ui/Accessible.pudu"
fidelity: Active
tags: [module, stdlib, ui, accessibility]
aliases: [Std Ui Accessible]
---

# Std Ui Accessible

## Purpose and interface

The text form in which a layout's accessibility tree crosses to the desktop adapter, and the form in
which the adapter reports back what assistive clients are told. Both directions are pure, so the
encoding is tested without a window.

- `type Exposed = { node, parent, role: Str, name, frame: Canvas.Rect, focused: Bool }`: one node as an
  assistive client sees it. `parent` is the node of the nearest meaningful ancestor, or `-1`.
- `snapshot(layout, focus: Option[Str]) -> Str`: every entry of `Layout.semantics` as one record,
  in reading order, with the node whose tag is `focus` marked focused.
- `decode(text) -> Result[Array[Exposed], AccessibleError]`: records back into values.
- `roleName(role) -> Str`: `decoration`, `group`, `heading`, `label`, `image`, `button`, `toggle`, or
  `field`. A snapshot never carries `decoration`, because `Layout.semantics` leaves those nodes out.
- `type AccessibleError = MalformedRecord(Int) | OrphanedRecord(Int)`: the zero-based record that
  could not be read, or whose parent no earlier record introduced.

A record is `node`, `parent`, `role`, `focused` (`0` or `1`), `x`, `y`, `width`, `height`, and
`name`, separated by tabs and ended by a newline. Frames are logical pixels from the top-left of the
window's content. The name is last, so it is the only field that may be empty.

## Semantics

- Tabs, carriage returns, and newlines inside a name become spaces, so no name can end its record
  or shift a field. A name is otherwise passed as written, including multi-byte text.
- Only a node that can take focus is marked focused; a focus tag naming anything else, or nothing
  in the layout, marks no node.
- `decode` refuses, as `MalformedRecord`, a record without exactly nine fields, a field that is not
  a number where one is required, or a focused flag other than `0` or `1`; and, as
  `OrphanedRecord`, a parent other than `-1` that is not the node of an earlier record, because the
  adapter builds each element under one it has already built. Empty lines are skipped.
- `decode` reads the adapter's report, whose roles are the platform's (`AXButton`), with the same
  parser: the role is carried as text, not mapped back.

## Grill Log

- **Q:** Encode the snapshot as JSON? **A:** No. _Rationale:_ the adapter already reads and writes
  tab-separated records for input, and a fixed nine-field record needs no parser beyond a split.
  _Rejected:_ a second encoding at the same boundary.
- **Q:** Escape tabs and newlines in names instead of replacing them? **A:** No. _Rationale:_ an
  assistive client speaks the name; a line break in a spoken label carries nothing a space does not.
  _Rejected:_ an escape grammar both sides must agree on.
- **Q:** Send the focus as a tag and let the adapter find the node? **A:** No. _Rationale:_ tags
  are a Pudu-side identity; the adapter should only read numbers and text. _Accepted:_ a focused
  flag per record.
- **Q:** Map the platform's roles back to `Layout.Role` in `decode`? **A:** No. _Rationale:_ the
  report exists to show what the platform was told; mapping it back would hide a wrong mapping.

## Referenced by

[[Std Ui Desktop]] · [[Std Ui Layout]] · [[Pudu Desktop Access]] · [[Uses Ui Accessible]] · [[Stdlib MOC]]
