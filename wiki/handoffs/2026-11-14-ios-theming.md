---
type: handoff
status: ACTIVE
issue: 923
aliases: [Native iOS Theming Delivery]
---

# Native iOS Theming Delivery

Language Architect → Backend Engineer. Owns [[Std Mobile Theme]], the theme additions to [[Std Mobile Stream]] and [[Std Mobile View]], [[iOS Host Theme]], [[Uses Mobile Theme]] and [[Native Themed Example]].

## Scope

Phase A visual system of [[Pudu Native iOS UI]]: semantic color roles with platform or fixed light/dark tones, an appearance override, and Dynamic Type text styles. Materials, symbols, elevation and continuous corners remain open. Stacked on [[Native iOS Scrolling Delivery]] (#919).

## Evidence

[[Uses Mobile Theme]] answers 12 interpreted and 12 as a native C11 executable. [[Uses Mobile View]] still answers 30 in both.

The full iOS simulator run passed on an Apple silicon Mac: the smoke app, Counter, Form, List, Feed, Themed, and both refusals. Themed reported `PUDU_THEME ink light #1F2A44FF dark #E8EEFFFF`, `PUDU_THEME appearance dark` and `PUDU_THEME type grows`.

The host file stays under 500 lines after the keyboard self-test moved into the layout header. The app now links QuartzCore for the media clock.

## Exact next action

Merge after #922 lands and CI is green; then step 4 of the order of work, recycling lists and grids.

## Referenced by

[[handoffs/_MOC]] · [[Pudu Native iOS UI]] · [[Native App Delivery]]
