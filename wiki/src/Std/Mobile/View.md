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

Pure description of a phone screen and the instruction stream that realizes it. A view is a tree of labels, buttons, rows, columns, text fields and toggles, where any control may be wrapped in a name. The module builds the stream of [[Pudu Native]] for a tree, a stream of changes between two trees, and decodes the events a host returns.

Exports:
- `type View = Label(Str) | Button(Str, UInt32) | Column(Array[View]) | Row(Array[View]) | Field(Str, Str, UInt32) | Toggle(Str, Bool, UInt32) | Named(Str, View)`: `Field` is a placeholder, a text and a tag; `Toggle` is a title, an on state and a tag; `Named` gives the wrapped control an accessible name and adds no node.
- `type Event = Tapped(UInt32) | Changed(UInt32, Str) | Toggled(UInt32, Bool) | Stopped`
- `build(view: &View) -> Bytes`: the full stream for a tree.
- `changes(shown: &View, next: &View) -> Bytes`: the stream that moves the screen from `shown` to `next`.
- `event(raw: UInt64, text: Str) -> Event`: decodes one value returned by a host wait, with the text the host fetched for it.
- `carriesText(raw: UInt64) -> Bool`: whether the event's text must be fetched before `event` is called.

## Invariants

- Pure: the module declares no foreign function. Platform calls live in [[Std Mobile Host]].
- A node is named by its position in a depth-first walk, root 0. `Named` adds no node, so a named control has the same name as the control alone. Trees of one shape name the same controls.
- `build` creates every node (CREATE), sets each label's text, each button's title and tag, each field's text, placeholder and tag, and each toggle's title, state and tag (TEXT, HINT, STATE, TAG), appends children to their row or column (APPEND), sets each accessible name (NAME), and ends with ROOT 0.
- `changes` updates in place when both trees have the same shape: the same variants, the same child counts and the same tags. It then emits only the instructions whose value differs: TEXT for label text, button titles, field text and toggle titles; HINT for a field's placeholder; STATE for a toggle's state; NAME for an accessible name. Any difference in variant, child count or tag resets the screen: it emits RESET followed by a full build.
- `event` reads the kind from the high 32 bits. Kind 1 is `Tapped` with the tag in the low 32 bits; kind 3 is `Changed` with the tag in the low 32 bits and the fetched text as its string; kind 4 is `Toggled` on and kind 5 is `Toggled` off, both with the tag in the low 32 bits; kind 2 is `Stopped`. Event decoding goes through a constant table `EVENTS` from event kind to constructor, so an unknown kind reads as `Stopped` without a branch per kind.
- `carriesText` is true only for kind 3. Only that kind has text to fetch.

## Negative Logic

- No keys, no removal, no partial structural diff. A shape change never emits a partial update.
- A tap names only the tag of its button. A toggle event names its tag and its new state. Only a `Changed` event carries text, and that text is fetched by the host, never packed into the 64-bit value.
- `event` never fails. An unknown kind is not an error and ends the loop the same way `Stopped` does.
- No I/O and no platform call. The host owns the foreign boundary.

## Dependencies and consumers

Depends on no other module. Consumers: [[Std Mobile Host]] (its `wait` decodes through `event`), [[Native Counter Example]], [[Native Form Example]], and the fixture [[Uses Mobile View]]. The native presenter of FUI targets this module, as [[Native Application UI]] describes.

## Resolved Grill Log

- **Q:** Why name nodes by position instead of keys? **A:** Phase 1 trees have a fixed shape. Keyed regions arrive with compiled views (ADR-0031, compiled native execution). _Rejected:_ keys before a reconciler needs them.
- **Q:** Why rebuild on a shape change? **A:** It is always correct, and the counter never changes shape; a reconciler replaces this path later. _Rejected:_ a partial structural diff with no reconciler behind it.
- **Q:** Why a table of constructors for events? **A:** Kinds dispatch through tables in this project; adding an event kind is one entry. _Rejected:_ a guard per kind.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile Host]] · [[Native First Light Delivery]] · [[Native Controls Delivery]]
