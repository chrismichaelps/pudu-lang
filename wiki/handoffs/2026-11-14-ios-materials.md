---
type: handoff
status: ACTIVE
issue: 928
aliases: [Native iOS Materials Delivery]
---

# Native iOS Materials Delivery

Language Architect → Backend Engineer. Owns the material additions to [[Std Mobile Theme]], [[Std Mobile Stream]] and [[Std Mobile View]], the iOS host material header [[iOS Host Material]], the fixture [[Uses Mobile Material]], the example [[Native Glass Example]], and the `glass-material` row of [[Backend Ledger]].

## Scope

The first platform API adopted through both gates of [[Native Platform Adoption]]: a surface material, glass on iOS 26 or later and a system blur otherwise. Stacked on [[Native Platform Ledger Delivery]] (#926). The iOS feature target it serves is [[Pudu Native iOS UI]], visual system row.

Ledger: `glass-material` needs SDK 26.0 and is listed in [[Backend Ledger]].

## Evidence

Uses Mobile Material answers 5 interpreted and 5 as a native C11 executable; the list (8), view (30) and theme (12) fixtures still pass in both. The host compiles with warnings as errors at the iOS 15 deployment target with unguarded-availability checking, so every glass call is behind the run-time gate. The same Glass app reported `PUDU_MATERIAL glass` on the iOS 26.4 simulator and `PUDU_MATERIAL blur` on the iOS 18.0 simulator. The full suite, the iPad matrix and the refusals passed. `pudu doctor --native` lists glass-material as available with SDK 26.5.

## Exact next action

Merge after #929 lands and CI is green; then #930, the remaining host capabilities in one pass.

## Referenced by

[[handoffs/_MOC]] · [[Native Platform Adoption]] · [[Pudu Native iOS UI]] · [[Native Platform Ledger Delivery]]
