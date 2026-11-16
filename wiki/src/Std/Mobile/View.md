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

Pure description of a phone screen and the reconciler that keeps it current. A view is a tree of labels, buttons, rows, columns, text fields and toggles, where any control may be wrapped in a name, and a column may hold keyed rows. A root scroll viewport holds one view. A recycling list holds a window of its items, so a long list costs the program only the rows the screen can show. `mount` builds a view and shows it; `update` compares the next view with the mounted tree and emits only the instructions that change the screen. Instructions are spelled by [[Std Mobile Stream]].

Exports:
- `type View = Label(Str) | Button(Str, UInt32) | Column(Array[View]) | Row(Array[View]) | Keyed(Array[(Str, View)]) | Field(Str, Str, UInt32) | Toggle(Str, Bool, UInt32) | Named(Str, View) | Scroll(View) | Styled(TextStyle, View) | Painted(Role, View) | Recycled(Window) | Surfaced(Material, View) | Progress(UInt32) | Activity(Bool) | Recognizing(UInt32, Array[Gesture.Kind], View) | Accessible(Access.Access, View) | Menu(UInt32, Array[Feedback.Choice], View) | Animated(View) | Control(Controls.Control)`: `Keyed` is a column whose rows carry keys; the platform sees a column. `Field` is a placeholder, a text and a tag; `Toggle` is a title, an on state and a tag; `Named` gives the wrapped control an accessible name and adds no node. `Scroll` creates a vertical viewport around one child. `Styled` gives the wrapped text control a text style and `Painted` gives it a color role; like `Named`, each adds no node. `Recycled` is a list of `total` items in `columns` equal columns: one column is a list, more are a grid. `Surfaced` is a container node of kind 9 whose background is a system material, holding one child. `Progress` is a determinate progress bar of kind 10 with its completion in thousandths; `Activity` is an activity indicator of kind 11 that spins when on. `Recognizing` attaches the recognizers of its kinds to the wrapped control, and their events report the tag. `Accessible` gives the wrapped control its traits, hint and value. `Menu` attaches a context menu of choices to the wrapped control. `Animated` makes the placements of a group animate. Like `Named`, the last four add no node. The module imports Std.Mobile.Control under the alias `Controls`. `Control` is one value control of [[Std Mobile Control]] (slider, stepper, segments, wheel, date, text area, search, symbol, pages or color well); it is the node itself, built and revised by that module.
- `type Window = { tag: UInt32, total: UInt32, first: UInt32, columns: UInt32, rows: Array[(Str, View)] }`: `rows` are the keyed views of items `first`, `first + 1`, and so on, the window the program currently supplies.
- `type Event = Tapped(UInt32) | Changed(UInt32, Str) | Toggled(UInt32, Bool) | Stopped | Reached(UInt32, UInt32) | Gestured(UInt32, Gesture.Gesture) | Chose(UInt32, UInt32) | Resized(Scene.Size) | Lifecycle(Scene.Phase) | Picked(UInt32, UInt32) | Valued(UInt32, Int32) | Colored(UInt32, UInt32) | Dated(UInt32, Int64)`: `Reached` names a list's tag and the index of its first visible item. `Gestured` reports a recognizer's phase and values. `Chose` names an alert's tag and the index of the choice taken. `Picked` names a context menu's tag and the index of its item. `Resized` reports the scene's size, and `Lifecycle` a lifecycle transition. `Valued` names a value control's tag and its value as Int32; `Colored` names a color well's tag and its packed RGBA color; `Dated` names a date picker's tag and whole seconds since the epoch.
- `type Shown = { id: UInt32, view: View, children: Array[Shown] }`: one node of the mounted tree, with the view it displays.
- `type Mounted = { root: Shown, next: UInt32, free: Array[UInt32] }`: the screen. `next` is the next fresh id; `free` holds recycled ids.
- `mount(view: &View) -> (Mounted, Bytes)`: builds the view with fresh ids and shows its root.
- `update(mounted: &Mounted, next: &View) -> (Mounted, Bytes)`: the mounted tree after `next` is shown, and the stream that moves the screen there.
- `windowStart(visible: UInt32, total: UInt32, size: UInt32) -> UInt32`: the `first` of a window of `size` items that places `visible` a quarter of the window from its start, clamped so the window never runs past `total`. Examples: (0, 100, 20) is 0; (50, 100, 20) is 45; (95, 100, 20) is 80; (3, 10, 20) is 0. A window should hold at least twice the items one screen shows; a smaller window moves at its edges more often.
- Event decoding (`event`, `carriesText`, `carriesDetail`, `carriesWords`, `eventWithDetail`, `eventWithWords` and `signed`) is in [[Std Mobile Decode]].

## Invariants

- Pure: the module declares no foreign function. Platform calls live in [[Std Mobile Host]].
- Every node has a stable id handed out by the program. An id is unchanged while its node stays on screen, so a reorder or an insertion never renumbers the rows around it.
- A node keeping its variant and tag updates in place: TEXT for label and button titles and field text, HINT for a field's placeholder, STATE for a toggle's state, NAME for an accessible name.
- A node changing its variant or tag is replaced: its new subtree is built, inserted at its index, and the old subtree removed. The root is replaced with ROOT, then the old root is removed.
- A scroll viewport keeps its node and reconciles its single child at index zero. A changed child kind replaces that child, preserving the viewport.
- Positional groups update their common children pairwise, append extra children, and remove missing ones.
- Keyed rows are matched by key. Rows whose key is gone are removed. Each wanted row is then updated in place; it is moved to its index only when its position differs, or built and inserted there. Only the first occurrence of a key can retain an old row. Later occurrences build fresh rows. After placing the new rows, any unclaimed old duplicates are removed and their subtree ids recycled.
- A `Recycled` list mounts CREATE kind 8, then TAG, COLUMNS, RANGE, and then each window row built and appended in order.
- Two `Recycled` views with the same tag reconcile their window rows by key, exactly as `Keyed` does. COLUMNS is written when the column count changed; RANGE is written when the total or the first index changed. A changed tag replaces the list.
- Removed ids go to `free` and are handed out again first, so the host's node table stays as large as the screen, not as large as every row ever shown.
- The `Event` type is defined here. Its kinds are decoded by [[Std Mobile Decode]], which reads the kind from the high 32 bits and the tag from the low 32 bits.
- The view module no longer writes RESET. The host keeps it so a stream from an earlier writer still means the same.
- `Styled` and `Painted` wrap the inner control and write STYLE or COLOR for its id after the inner control is built. Wrappers of the same kind on both sides reconcile the inner node and write STYLE or COLOR only when the style or role changed.
- STYLE and COLOR apply only to labels, buttons, fields and toggles. The host refuses them on a group.
- `Surfaced` mounts CREATE kind 9, then MATERIAL with its material code, then its child built and appended. A changed material writes one MATERIAL for the surface's id. The child reconciles at index zero, as a scroll viewport's does, and a changed child kind replaces only that child.
- `mount` and `update` emit no theme instruction. A theme is a separate commit made with `Std.Mobile.Host` `apply`, using [[Std Mobile Theme]]'s `stream`.
- `Progress` mounts CREATE kind 10 then VALUE for its id. A changed completion writes one VALUE, and an unchanged one writes nothing.
- `Activity` mounts CREATE kind 11 then STATE. A changed state writes one STATE.
- `Recognizing` writes one GESTURES for its node after the inner control is built. An update rewrites GESTURES only when its tag or its recognizer set changed.
- `Accessible` writes TRAITS, ACCESS_HINT and ACCESS_VALUE after the inner control is built. An update writes only the fields that changed.
- `Menu` writes one MENU after the inner control is built. An update rewrites it only when its tag or its choices changed.
- `Animated` writes ANIMATE on at mount. An update writes nothing for it.
- A wrapper of the same kind on both sides reconciles its inner view as `Styled` does. A different wrapper kind replaces the node.
- Measured events, kinds 9 and 11, carry up to four signed words, read by the host through the word channel of [[iOS Host Events]]. Detailed events, kinds 8, 10, 12 and 13, carry their index or code in the detail word. Kind 9 carries its recognizer bit as the detail word.

## Negative Logic

- No partial update of a changed shape: a replaced subtree is always built whole.
- A wrapper added, removed, or swapped for another kind of wrapper replaces the node, as any variant change does.
- No style or role is applied to a group, and no color is resolved for an appearance in this module.
- No move when the position is unchanged: an unchanged order writes nothing.
- No node is replaced for a text change; only a variant or tag change replaces it.
- No row outside the window is built. Pudu never builds rows outside the window it supplies. A row node whose item leaves the window is removed with its subtree, and its ids are recycled.
- No cell reuse here. The platform reuses cells; this module creates a row view only for a row entering the window.
- No RANGE or COLUMNS is written for an unchanged list.
- No detail is read for a kind outside `DETAILED` and `MEASURED`.
- A tap names only the tag of its button. A toggle event names its tag and its new state. Only a `Changed` event carries text, fetched by the host and never packed into the 64-bit value.
- No I/O and no platform call. The host owns the foreign boundary.

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the instruction words, on [[Std Mobile Theme]] for the `TextStyle`, `Role` and `Material` sums, and on [[Std Mobile Gesture]], [[Std Mobile Scene]], [[Std Mobile Access]], [[Std Mobile Feedback]] and [[Std Mobile Control]] for the values of the new variants, and on [[Std Mobile Decode]] for the decoding of events. Consumers: [[Std Mobile Host]] (its `wait` decodes through [[Std Mobile Decode]]), [[Native Counter Example]], [[Native Form Example]], [[Native List Example]], [[Native Catalog Example]], and the fixtures [[Uses Mobile View]], [[Uses Mobile List]], [[Uses Mobile Capabilities]], and the example [[Native Showcase Example]]. The native presenter of FUI targets this module, as [[Native Application UI]] describes.

## Resolved Grill Log

- **Q:** Why a single child? **A:** Columns and keyed lists already describe groups. The viewport owns scrolling and uses the same child placement instructions.

- **Q:** Why stable ids instead of positions? **A:** Positions change under insertion, which would rebuild everything after it. _Rejected:_ positional ids with keys only as hints.
- **Q:** Why move only when the position differs? **A:** An unchanged order writes nothing; a reorder writes one MOVE per displaced row. _Rejected:_ moving every keyed row on each update.
- **Q:** What happens to old duplicate rows after a keyed update? **A:** The placed prefix is the complete new list. Remove the remaining suffix, which contains only unclaimed old duplicates, so no visible row lives outside the mounted tree. _Rejected:_ retaining old rows solely because their key still exists.
- **Q:** Why recycle ids? **A:** The host's node table stays as large as the screen, not as large as every row ever shown.
- **Q:** Why a table of constructors for events? **A:** Kinds dispatch through tables in this project; adding an event kind is one entry. _Rejected:_ a guard per kind.
- **Q:** Why a container rather than a wrapper like Styled? **A:** A material is drawn by its own platform view behind its content, so it is a node with one child.
- **Q:** Why wrappers rather than fields on every control? **A:** Most controls take the platform default; a wrapper costs nothing when absent and keeps every existing constructor and stream unchanged.
- **Q:** Why does Pudu supply a window rather than every item? **A:** Encoding a thousand rows each commit would dominate a frame; a window bounded by the screen keeps commits proportional to what can be seen. _Rejected:_ building every row up front.
- **Q:** Why does the host report only the first visible index? **A:** The program picks the window size; one index is enough to place it, and it fits the one-word detail channel. _Rejected:_ a range packed into the tag word.
- **Q:** Why a table of detailed event kinds? **A:** Kinds dispatch through tables; a new detailed event is one entry.
- **Q:** Why move decoding out of View? **A:** Decoding depends only on the Event type; moving it is a pure split with no behavior change, and frees the budget for the new cases. See [[Std Mobile Decode]].
- **Q:** One wrapper case or ten View cases? **A:** One `Control` case; [[Std Mobile Control]] owns the value controls' build and revision, and View stays under the line budget.

- **Q:** Why signed words for gestures and scene values? **A:** A pan moves left or up, so its translation is negative. The host sends the bits of each value, and the program reads two's complement, so the sign is exact. _Rejected:_ a separate sign word.
- **Q:** Why does a new wrapper add no node? **A:** Accessibility, recognizers, menus and animation describe a control that already exists. A node per wrapper would add ids the platform never shows.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile Host]] · [[Std Mobile Stream]] · [[Std Mobile Theme]] · [[Native First Light Delivery]] · [[Native Controls Delivery]] · [[Native Keyed Lists Delivery]] · [[Native iOS Scrolling Delivery]] · [[Native iOS Theming Delivery]] · [[Native iOS Recycling Delivery]] · [[Native iOS Materials Delivery]] · [[Std Mobile Control]] · [[Std Mobile Decode]] · [[Native iOS Controls Delivery]]
