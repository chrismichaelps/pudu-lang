---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Ui/Screen.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, input, focus, state]
aliases: [Std Ui Screen]
---

# Std Ui Screen

## Purpose and interface

A running application screen as a value. `Screen[S]` holds a state, a view function from state to
[[Std Ui Layout]] `View`, an update function from state and `Event` to state, and the frame last
produced: its layout, its pixels, the tag holding focus, and the regions that changed.

`start` places, paints, and renders the first frame. `handle` applies one `Input` and `handleAll`
applies several in order. `stateOf`, `layoutOf`, `surfaceOf`, `damagedOf`, and `focusOf` observe the
current frame. `Input` is `Pressed(point)` or `KeyPressed(key)`; `Key` is `Next`, `Previous`,
`Activate`, or `Dismiss`. `Event` is `Activated(tag)` or `Dismissed`. `ScreenError` carries either a
placement refusal or a drawing refusal unchanged.

## Governance and algorithm

**Input resolves through placement, never through pixels.** A press asks `hitTest` for the frontmost
meaningful node; only a control produces an event, and the press moves focus to it. `Next` and
`Previous` walk `focusOrder` and wrap; from no focus they start at the first or last control.
`Activate` activates the focused control. An input that produces no event returns the same frame with
no damage, so a presenter can skip presenting.

**A control is identified by its tag.** Placement already refuses duplicate control tags, so an event
cannot be ambiguous about its source, and a tag defaults to the accessible name so ordinary controls
need no extra identity. Two "Delete" buttons in a list carry distinct tags and the same spoken name.

**Every update produces damage, and damage produces pixels.** After an event the new state is placed
and painted; `Layout.damage` against the previous placement names the changed regions, and
`Canvas.repaint` redraws only those into the previous surface. The fixture requires the resulting
bytes to equal a fresh `start` at the same state, so incremental frames cannot drift from full ones.

**Focus is always visible.** The focused control is drawn with a one-pixel ring just outside its
frame, composed after the layout's fills and text so no control can cover it. `focusRing` changes
the ring's color and `defaultRing` names the starting color. Moving focus damages the ring region it
left and the one it reached, clipped to the viewport and recorded once; an update damages the layout's
regions plus both rings. The fixture compares every such frame with a reference built from layout,
canvas, and explicit ring edges rather than from the screen itself.

**Text reaches only a focused field.** `TypedText` delivers `Typed(tag, text)` and the `Erase` key
delivers `Erased(tag)`, but only when focus is on a control that means `Field`; with focus on a button,
or nowhere, text changes nothing and damages nothing, and empty text is ignored. The screen never edits
state itself: the update decides what typing and erasing mean, so a field's contents stay one value in
state that the view shows.

**An unchanged view stops the update.** A screen keeps the view it last placed. When an update gives
a new state whose view equals that view and focus is unchanged, the state is kept and placement,
painting, and repaint are skipped with no damage—the same rule a dependency graph uses to stop
propagation when a recomputed value equals the old one.

**Focus follows identity across updates.** If the focused tag still names a control after an update it
stays focused; if the control disappeared, focus becomes none rather than jumping to a neighbour the
person did not choose.

**Keys are named by action.** A platform presenter maps its own keycaps and text-direction conventions
to `Next`, `Previous`, `Activate`, and `Dismiss` once; the screen never sees a keyboard layout.

## Referenced archive material

The archived Core Animation guide separates the state an application sets from the frame being
presented; here the state, the placement, and the presented surface are three fields of one value
updated together. The archived view-drawing guide's coalesced invalidation becomes the damage list
each update returns.

## Grill Log

- **Q:** Attach closures to controls, as views with embedded actions do? **A:** No. _Rationale:_ a
  view holding functions cannot be compared, and comparison is how placement, damage, and tests work.
  _Rejected:_ per-control closures; events carry the control's tag to one update function.
- **Q:** Route a press to whatever pixel is under it? **A:** No. _Rationale:_ decoration must not take
  a press meant for what it holds. _Rejected:_ pixel-based picking.
- **Q:** Move focus to a neighbour when the focused control disappears? **A:** No. _Rationale:_ a
  focus the person did not choose can activate the wrong thing. _Rejected:_ implicit refocus.
- **Q:** Repaint everything after each event? **A:** No. _Rationale:_ damage is already known from
  placement. _Rejected:_ full redraw; equality with a fresh start is checked instead.
- **Q:** Model keycodes? **A:** No. _Rationale:_ layouts and platforms differ; actions do not.
  _Rejected:_ keyboard-layout-specific inputs in the portable core.

Resolved Grill Log: inputs become tagged events through placement, updates repaint only damage with
equality to a full frame, and focus survives updates only while its control does.

## Referenced by

Depends on [[Std Ui Layout]], [[Std Ui Canvas]], and [[Std Option]].

Consumed by [[Uses Ui Screen]] and [[Service Evaluation Spec]].

[[src/Std/_MOC]] · [[Native Application UI]] · [[2026-09-12-release-readiness-ui]]
