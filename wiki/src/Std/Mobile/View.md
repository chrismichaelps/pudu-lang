---
type: module
path: "@root/lib/Std/Mobile/View.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile View]
---

# Std Mobile View

## Purpose and interface

Pure description of a phone screen and the instruction stream that realizes it. A view is a tree of labels, buttons and columns. The module builds the version 0 stream of [[Pudu Native]] for a tree, a stream of changes between two trees, and decodes the events a host returns.

Exports:
- `type View = Label(Str) | Button(Str, UInt32) | Column(Array[View])`
- `type Event = Tapped(UInt32) | Stopped`
- `build(view: &View) -> Bytes`: the full stream for a tree.
- `changes(shown: &View, next: &View) -> Bytes`: the stream that moves the screen from `shown` to `next`.
- `event(raw: UInt64) -> Event`: decodes one value returned by a host wait.

## Invariants

- Pure: the module declares no foreign function. Platform calls live in [[Std Mobile Host]].
- A node is named by its position in a depth-first walk, root 0. Trees of one shape name the same controls.
- `build` creates every node (CREATE), sets each label's text and each button's title and tag (TEXT, TAG), appends children to their column (APPEND), and ends with ROOT 0.
- `changes` emits only TEXT instructions for labels and button titles whose text differs, when both trees have the same shape: same variants, same child counts, same button tags. Otherwise it emits RESET followed by a full build.
- `event` reads the kind from the high 32 bits. Kind 1 is `Tapped` with the tag in the low 32 bits; kind 2 is `Stopped`. Any other kind reads as `Stopped`.

## Negative Logic

- No keys, no removal, no partial structural diff. A shape change never emits a partial update.
- Events carry no text and no node name; a tap names only the tag of its button.
- `event` never fails. An unknown kind is not an error and ends the loop the same way `Stopped` does.
- No I/O and no platform call. The host owns the foreign boundary.

## Dependencies and consumers

Depends on no other module. Consumers: [[Std Mobile Host]] (its `wait` decodes through `event`), [[Native Counter Example]], and the fixture [[Uses Mobile View]]. The native presenter of FUI targets this module, as [[Native Application UI]] describes.

## Resolved Grill Log

- **Q:** Why name nodes by position instead of keys? **A:** Phase 1 trees have a fixed shape. Keyed regions arrive with compiled views (ADR-0031, compiled native execution). _Rejected:_ keys before a reconciler needs them.
- **Q:** Why rebuild on a shape change? **A:** It is always correct, and the counter never changes shape; a reconciler replaces this path later. _Rejected:_ a partial structural diff with no reconciler behind it.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile Host]] · [[Native First Light Delivery]]
