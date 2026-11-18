---
type: handoff
status: ACTIVE
issue: 925
aliases: [Native iOS Recycling Delivery]
---

# Native iOS Recycling Delivery

Language Architect → Backend Engineer. Owns the list additions to [[Std Mobile View]], [[Std Mobile Stream]] and [[Std Mobile Host]], [[iOS Host Events]], [[iOS Host List]], [[Uses Mobile List]] and [[Native Catalog Example]].

## Scope

Step 4 of the order of work in [[Pudu Native iOS UI]]: recycling lists and equal-column grids. A list is a `Recycled` view that names its total item count and supplies rows for a window; the platform owns cell reuse, and Pudu owns identity and the window of row models. Stacked on [[Native iOS Theming Delivery]] (#923).

Sections, compositional layouts beyond equal columns, pull to refresh and nested scrolling remain open.

## Evidence

Uses Mobile List answers 8 interpreted and 8 as a native C11 executable. Uses Mobile View (30) and Uses Mobile Theme (12) still pass in both.

The full iOS simulator run passed: smoke, Counter, Form, List, Feed, Themed, Catalog, and the refusals. Catalog scrolled from the first item to the last, showed Item 1000, and ended with the window clamped to Item 881 through Item 1000. 100 cells were made for 1,000 items.

Testing exposed and fixed an edge alternation when the window was too small for the screen, and an iOS 16-only layout call under the iOS 15 deployment target. The control layer moved into [[iOS Host Controls]], leaving the host at about 400 lines.

## Exact next action

Merge after #924 lands and CI is green; then step 5 of the order of work, size-class adaptivity and multiple windows.

## Referenced by

[[handoffs/_MOC]] · [[Pudu Native iOS UI]] · [[Native App Delivery]]
