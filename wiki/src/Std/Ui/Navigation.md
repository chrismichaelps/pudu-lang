---
type: module
path: "@root/lib/Std/Ui/Navigation.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, desktop, navigation, modal]
aliases: [Std Ui Navigation]
---

# Std Ui Navigation

## Purpose and interface

Where the person is in an application, as values: a stack of pages, tabs, a split view, and what is
presented modally.

Exports:
- `type Stack[P]`: `stack`, `push`, `pop`, `popToRoot`, `top`, `canGoBack`, `depth`, `backButton`,
  `navigated` (`back` or `Dismissed` pops).
- `type Tabs`: `tabs`, `chose` (controls tagged `tab.<tag>`), `tabbed`.
- `split(sidebar, detail, width, theme)`.
- `type Choice`, `type Presented = Nothing | Sheet(id) | Alert(title, message, choices) |
  Confirm(title, message, choice)`: `choice`, `destructive`, `presentedAfter`, `presenting`.

## Semantics

- The root page is never popped.
- `presenting` layers a dimmed scrim and a centred card over the view. The scrim is a group rather
  than decoration because hit testing passes through decoration; it stops presses from reaching
  the view beneath, which the fixture asserts.
- A destructive choice is drawn with the danger color as its accent, so its text stays readable.
- A confirmation always offers `cancel`; `Dismissed` closes anything presented.

## Grill Log

- **Q:** Navigation as a hidden router owned by the framework? **A:** No. _Rationale:_ the stack is
  part of the state, so restoring a window, deep-linking, and testing a flow are all values.
  _Rejected:_ an imperative navigator object.
- **Q:** Does a modal trap keyboard focus? **A:** Not yet. Presses are blocked; focus order still
  includes controls beneath. Trapping focus needs a focus scope in [[Std Ui Screen]] and is queued.

## Dependencies and consumers

- Depends on [[Std Ui Controls]], [[Std Ui Layout]], [[Std Ui Screen]], [[Std Ui Theme]],
  [[Std Ui Canvas]].
- Consumed by application views.

## Referenced by

[[src/Std/_MOC]] · [[architecture/NATIVE-UI]]
