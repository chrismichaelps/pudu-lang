---
type: module
path: "@root/lib/Std/Ui/Controls.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, controls, accessibility]
aliases: [Std Ui Controls]
---

# Std Ui Controls

## Purpose and interface

Standard controls as [[Std Ui Layout]] views, styled by [[Std Ui Theme]], and the update helpers
that read their [[Std Ui Screen]] events.

Views: `button`, `quietButton`, `toggle`, `stepper` (tags `tag.down` and `tag.up`), `picker` (tags
`tag.0`, `tag.1`, …), `progress`, `field`, `secureField`, `heading`, `caption`.

Updates: `toggled(on, event, tag)`, `stepped(value, event, tag, low, high, step)`,
`picked(selected, event, tag, count)`, `edited(value, event, tag, limit)`.

## Semantics

- Every control carries its role and a spoken name that includes its state: `Sync, on`,
  `Dark, selected`, `Upload 40 percent`. A secure field is named by its title only, so its value is
  never read aloud.
- State stays in the program: a view shows a value, an update returns the next one, and an update
  ignores events from any other control.
- Out-of-range input is held, not refused: a stepper stops at its bounds, a progress bar clamps to
  0–100, a field stops at its limit.

## Grill Log

- **Q:** Controls that own their state? **A:** No. _Rationale:_ a control holding state is a second
  source of truth the program must synchronise; one state value keeps undo, persistence, and tests
  exact. _Rejected:_ stateful widgets with change callbacks.
- **Q:** Sliders? **A:** Not yet: a slider is a drag, and the adapter reports presses but not pointer
  motion. The coverage table in [[architecture/NATIVE-UI]] records it.

## Dependencies and consumers

- Depends on [[Std Ui Layout]], [[Std Ui Screen]], [[Std Ui Theme]].
- Consumed by [[Std Ui Navigation]] and application views.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
