---
type: module
path: "@root/lib/Std/Mobile/Stream.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile Stream]
---

# Std Mobile Stream

## Purpose and interface

Pure encoder of the view stream of [[Pudu Native]]. The reconciler in [[Std Mobile View]] decides which changes a commit needs; this module owns how each instruction is spelled as words and bytes. Every function takes the stream so far and answers it extended.

Exports:
- Kinds, values 1 to 9: `LABEL`, `BUTTON`, `COLUMN`, `ROW`, `FIELD`, `TOGGLE`, `SCROLL`, `LIST`, `MATERIAL`. Kinds 7 and 8 use the existing group instructions; a list additionally takes RANGE and COLUMNS. Kind 9 is a container of one child, as a scroll viewport is.
- `create(out: Array[UInt8], node: UInt32, kind: UInt32) -> Array[UInt8]`: CREATE, the node and its kind.
- `text(out, node, value: Str) -> Array[UInt8]`: TEXT, the node, then the text.
- `hint(out, node, value: Str) -> Array[UInt8]`: HINT, the node, then the placeholder text.
- `name(out, node, value: Str) -> Array[UInt8]`: NAME, the node, then the accessible name.
- `tag(out, node, value: UInt32) -> Array[UInt8]`: TAG, the node and the tag its events report.
- `state(out, node, on: Bool) -> Array[UInt8]`: STATE, the node and 0 or 1.
- `append(out, parent: UInt32, child: UInt32) -> Array[UInt8]`: APPEND, a group and a child.
- `insert(out, parent, child, index: UInt32) -> Array[UInt8]`: INSERT, a group, a child and the index it takes.
- `move(out, parent, child, index: UInt32) -> Array[UInt8]`: MOVE, a group, a child and its new index.
- `remove(out, node, ids: &Array[UInt32]) -> Array[UInt8]`: REMOVE, the node, the count of ids, then every id of the detached subtree.
- `root(out, node: UInt32) -> Array[UInt8]`: ROOT, the node shown as the screen's content.
- `theme(out, tones: &Array[(UInt32, UInt32, UInt32)]) -> Array[UInt8]`: THEME, the count of tones, then one kind, light word and dark word per role in role order.
- `appearance(out, code: UInt32) -> Array[UInt8]`: APPEARANCE and its code.
- `style(out, node: UInt32, code: UInt32) -> Array[UInt8]`: STYLE, the node and its text style code.
- `color(out, node: UInt32, code: UInt32) -> Array[UInt8]`: COLOR, the node and its role code.
- `range(out, node: UInt32, total: UInt32, first: UInt32) -> Array[UInt8]`: RANGE, the list node, its total item count and the index of its first window row.
- `columns(out, node: UInt32, count: UInt32) -> Array[UInt8]`: COLUMNS, the list node and its column count.
- `material(out, node: UInt32, code: UInt32) -> Array[UInt8]`: MATERIAL, the material node and its material code.

## Invariants

- Every word is a little-endian 32-bit unsigned value. Every instruction begins with its code word (CREATE 1, TEXT 2, APPEND 3, ROOT 4, TAG 5, STATE 7, HINT 8, NAME 9, INSERT 10, REMOVE 11, MOVE 12, THEME 20, APPEARANCE 21, STYLE 22, COLOR 23, RANGE 24, COLUMNS 25, MATERIAL 26).
- Theming codes start at 20. Navigation reserves 13 and 14, so a gap keeps both streams unambiguous when they merge.
- RANGE is exactly three words after its code word; COLUMNS is exactly two; MATERIAL is exactly two. A RANGE is 16 bytes, a COLUMNS is 12 bytes and a MATERIAL is 12 bytes.
- THEME carries exactly seven tones; its count word is 7. The encoder writes the count, and the host refuses any other count.
- Text is its UTF-8 byte length as one word, followed by those bytes.
- `remove` writes the node, then the count of ids, then every id of the detached subtree, so the host can forget each one.
- Each function appends to the stream it is given and returns the extended stream; no function reads or reorders earlier bytes.

## Negative Logic

- No decisions: the encoder never chooses which instruction a commit needs, never compares two trees, and never allocates a node id.
- No RESET. The view module no longer writes RESET, and this encoder does not spell it.
- No validation of node ids, indices or kinds. Refusing a bad instruction is the host's job, in [[iOS Host Adapter]].
- No window arithmetic. The first index and the total are passed through as given; [[Std Mobile View]] decides them.
- No I/O and no platform call.

## Dependencies and consumers

Depends on no other module. Consumer: [[Std Mobile View]], which calls these functions to build the stream of each mount and update.

## Resolved Grill Log

- **Q:** Add a separate scroll instruction? **A:** CREATE identifies the viewport as a kind. APPEND, INSERT and REMOVE maintain its child.

- **Q:** Why a separate encoder module? **A:** The reconciler decides what changes; the encoder owns how an instruction is spelled, so neither grows into the other. _Rejected:_ one module for both.

- **Q:** Why codes 20 to 23 rather than the next free numbers? **A:** The navigation slice claims 13 and 14 in parallel; a gap keeps both streams unambiguous when they merge.

- **Q:** Why codes 24 and 25 for RANGE and COLUMNS? **A:** They continue after the theming codes without a gap, since no other slice claims them. A list's window and its grid shape are separate instructions, so a change to one writes only that instruction.
- **Q:** Why code 26 for MATERIAL? **A:** It continues the sequence with no gap. A material is one word of kind and one word of code, so a change of material writes one fixed-size instruction.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Theme]] · [[Native Keyed Lists Delivery]] · [[Native iOS Scrolling Delivery]] · [[Native iOS Theming Delivery]] · [[Native iOS Recycling Delivery]] · [[Native iOS Materials Delivery]]
