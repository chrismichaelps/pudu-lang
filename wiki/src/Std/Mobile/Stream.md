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
- Kinds, values 1 to 7: `LABEL`, `BUTTON`, `COLUMN`, `ROW`, `FIELD`, `TOGGLE`, `SCROLL`. Kind 7 uses the existing group instructions.
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

## Invariants

- Every word is a little-endian 32-bit unsigned value. Every instruction begins with its code word (CREATE 1, TEXT 2, APPEND 3, ROOT 4, TAG 5, STATE 7, HINT 8, NAME 9, INSERT 10, REMOVE 11, MOVE 12).
- Text is its UTF-8 byte length as one word, followed by those bytes.
- `remove` writes the node, then the count of ids, then every id of the detached subtree, so the host can forget each one.
- Each function appends to the stream it is given and returns the extended stream; no function reads or reorders earlier bytes.

## Negative Logic

- No decisions: the encoder never chooses which instruction a commit needs, never compares two trees, and never allocates a node id.
- No RESET. The view module no longer writes RESET, and this encoder does not spell it.
- No validation of node ids, indices or kinds. Refusing a bad instruction is the host's job, in [[iOS Host Adapter]].
- No I/O and no platform call.

## Dependencies and consumers

Depends on no other module. Consumer: [[Std Mobile View]], which calls these functions to build the stream of each mount and update.

## Resolved Grill Log

- **Q:** Add a separate scroll instruction? **A:** CREATE identifies the viewport as a kind. APPEND, INSERT and REMOVE maintain its child.

- **Q:** Why a separate encoder module? **A:** The reconciler decides what changes; the encoder owns how an instruction is spelled, so neither grows into the other. _Rejected:_ one module for both.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Native Keyed Lists Delivery]] · [[Native iOS Scrolling Delivery]]
