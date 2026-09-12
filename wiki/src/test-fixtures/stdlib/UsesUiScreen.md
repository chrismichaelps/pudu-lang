---
type: module
path: "@root/test-fixtures/stdlib/UsesUiScreen.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, ui, input]
aliases: [Uses Ui Screen]
---

# Uses Ui Screen

## Purpose and interface

Executable Pudu fixture for interactive screens. A counter with increment and reset controls over an
indicator whose color follows the count; the reset control is absent at two and after dismissal. Its
`main` returns 16 held assertions.

Refusals: an unnamed button and duplicate control tags surface as placement errors, and a transparent
background surfaces as a drawing error.

Frames: the first frame damages the whole viewport; a press on a control updates state, focuses the
control, damages only the indicator, and yields bytes equal to a fresh start at the new state; presses
on decoration or outside the viewport change nothing and damage nothing.

Focus: `Next` wraps through controls, `Previous` starts from the last control, `Activate` without focus
does nothing, `Dismiss` reaches the update, focus survives an update while its control exists, and
focus becomes none when the focused control disappears. A sequence that hides a control still matches
a fresh start byte for byte.

## Grill Log

- **Q:** Check state alone after input? **A:** No. _Rationale:_ incremental repaint can be wrong while
  state is right. _Rejected:_ state-only assertions; frames are compared to fresh starts.

## Referenced by

[[Std Ui Screen]] · [[Service Evaluation Spec]]
