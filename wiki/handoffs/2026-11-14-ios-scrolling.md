---
type: handoff
status: ACTIVE
issue: 919
aliases: [Native iOS Scrolling Delivery]
---

# Native iOS Scrolling Delivery

Language Architect → Backend Engineer. Owns the scroll variant in [[Std Mobile View]], its
wire kind in [[Std Mobile Stream]], root geometry and focus in [[iOS Host Layout]], and
verification in [[Uses Mobile View]], [[Native Feed Example]] and [[iOS Simulator Run]].

## Scope

Phase A of [[Pudu Native iOS UI]]. The branch carries the keyed-list and simulator-app commits
so it can exercise the current view and packaging contracts while their reviews run. The first
scroll viewport is vertical and fills the root layout. The host uses its existing group operations
for the wrapped child. The viewport follows the safe area and docked keyboard guide.

## Evidence

The stream fixture passes in interpreted and native execution. On iOS 26.4 the 40-row feed
reported a scrollable safe-area viewport, the focused field visible above the docked keyboard,
and the original viewport restored after dismissal. Creating the root guide before the window
was visible left the viewport height unchanged when the keyboard appeared.

## Exact next action

Run the full gates on the integrated #919 head after #915 and #918 land, then obtain independent
public-contract and vault-parity review.

## Referenced by

[[handoffs/_MOC]] · [[Pudu Native iOS UI]] · [[Native App Delivery]]
