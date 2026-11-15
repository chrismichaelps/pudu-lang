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

Pure description of a phone screen and the reconciler that keeps it current. A view is a tree of labels, buttons, rows, columns, text fields and toggles, where any control may be wrapped in a name, and a column may hold keyed rows. A root scroll viewport holds one view. `mount` builds a view and shows it; `update` compares the next view with the mounted tree and emits only the instructions that change the screen. Instructions are spelled by [[Std Mobile Stream]].

Exports:
- `type View = Label(Str) | Button(Str, UInt32) | Column(Array[View]) | Row(Array[View]) | Keyed(Array[(Str, View)]) | Field(Str, Str, UInt32) | Toggle(Str, Bool, UInt32) | Named(Str, View) | Scroll(View)`: `Keyed` is a column whose rows carry keys; the platform sees a column. `Field` is a placeholder, a text and a tag; `Toggle` is a title, an on state and a tag; `Named` gives the wrapped control an accessible name and adds no node. `Scroll` creates a vertical viewport around one child.
- `type Event = Tapped(UInt32) | Changed(UInt32, Str) | Toggled(UInt32, Bool) | Stopped`
- `type Shown = { id: UInt32, view: View, children: Array[Shown] }`: one node of the mounted tree, with the view it displays.
- `type Mounted = { root: Shown, next: UInt32, free: Array[UInt32] }`: the screen. `next` is the next fresh id; `free` holds recycled ids.
- `mount(view: &View) -> (Mounted, Bytes)`: builds the view with fresh ids and shows its root.
- `update(mounted: &Mounted, next: &View) -> (Mounted, Bytes)`: the mounted tree after `next` is shown, and the stream that moves the screen there.
- `event(raw: UInt64, text: Str) -> Event`: decodes one value returned by a host wait, with the text the host fetched for it.
- `carriesText(raw: UInt64) -> Bool`: whether the event's text must be fetched before `event` is called.

Presenters with multiple roots use `Work` to share an allocator and output buffer.
`buildBody` creates a detached body. `reconcileBody` returns the updated body and
work in `Kept` or `Replaced` when the caller must build another root. `removeBody`
retires the tree and releases its IDs after the caller changes the presentation.

## Invariants

- Pure: the module declares no foreign function. Platform calls live in [[Std Mobile Host]].
- Every node has a stable id handed out by the program. An id is unchanged while its node stays on screen, so a reorder or an insertion never renumbers the rows around it.
- A node keeping its variant and tag updates in place: TEXT for label and button titles and field text, HINT for a field's placeholder, STATE for a toggle's state, NAME for an accessible name.
- A node changing its variant or tag is replaced: its new subtree is built, inserted at its index, and the old subtree removed. The root is replaced with ROOT, then the old root is removed.
- A scroll viewport keeps its node and reconciles its single child at index zero. A changed child kind replaces that child, preserving the viewport.
- Positional groups update their common children pairwise, append extra children, and remove missing ones.
- Keyed rows are matched by key. Rows whose key is gone are removed. Each wanted row is then updated in place; it is moved to its index only when its position differs, or built and inserted there. Only the first occurrence of a key can retain an old row. Later occurrences build fresh rows. After placing the new rows, any unclaimed old duplicates are removed and their subtree ids recycled.
- Removed ids go to `free` and are handed out again first, so the host's node table stays as large as the screen, not as large as every row ever shown.
- Events are unchanged: `event` reads the kind from the high 32 bits. Kind 1 is `Tapped` with the tag in the low 32 bits; kind 3 is `Changed` with the tag and the fetched text; kind 4 is `Toggled` on and kind 5 is `Toggled` off, both with the tag; kind 2 is `Stopped`. Decoding goes through the constant table `EVENTS`, so an unknown kind reads as `Stopped`.
- `carriesText` is true only for kind 3.
- The view module no longer writes RESET. The host keeps it so a stream from an earlier writer still means the same.

## Negative Logic

- No partial update of a changed shape: a replaced subtree is always built whole.
- No move when the position is unchanged: an unchanged order writes nothing.
- No node is replaced for a text change; only a variant or tag change replaces it.
- A tap names only the tag of its button. A toggle event names its tag and its new state. Only a `Changed` event carries text, fetched by the host and never packed into the 64-bit value.
- `event` never fails. An unknown kind ends the loop the same way `Stopped` does.
- No I/O and no platform call. The host owns the foreign boundary.

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the instruction words. Consumers: [[Std Mobile Host]] (its `wait` decodes through `event`), [[Native Counter Example]], [[Native Form Example]], [[Native List Example]], and the fixture [[Uses Mobile View]]. The native presenter of FUI targets this module, as [[Native Application UI]] describes.

## Completed navigation events

`eventWithDetail(raw, text, detail)` decodes kind 6 as `Popped(from, destination)`,
using the low word and detail word respectively. `carriesDetail` is true for
kind 6. Existing event kinds and two-argument decoding retain their behavior.

## Resolved Grill Log

- **Q:** Change the meaning of the text field? **A:** Completed pops use a
  separate UInt32 detail. Text continues to carry only changed field input.

- **Q:** Allocate IDs independently for each page? **A:** Share the view allocator
  across a presentation. The host can resolve every body from the one node table.
  Root publication and retirement ordering belong to the presenter.

- **Q:** Why a single child? **A:** Columns and keyed lists already describe groups. The viewport owns scrolling and uses the same child placement instructions.

- **Q:** Why stable ids instead of positions? **A:** Positions change under insertion, which would rebuild everything after it. _Rejected:_ positional ids with keys only as hints.
- **Q:** Why move only when the position differs? **A:** An unchanged order writes nothing; a reorder writes one MOVE per displaced row. _Rejected:_ moving every keyed row on each update.
- **Q:** What happens to old duplicate rows after a keyed update? **A:** The placed prefix is the complete new list. Remove the remaining suffix, which contains only unclaimed old duplicates, so no visible row lives outside the mounted tree. _Rejected:_ retaining old rows solely because their key still exists.
- **Q:** Why recycle ids? **A:** The host's node table stays as large as the screen, not as large as every row ever shown.
- **Q:** Why a table of constructors for events? **A:** Kinds dispatch through tables in this project; adding an event kind is one entry. _Rejected:_ a guard per kind.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile Host]] · [[Std Mobile Stream]] · [[Native First Light Delivery]] · [[Native Controls Delivery]] · [[Native Keyed Lists Delivery]] · [[Native iOS Scrolling Delivery]]
