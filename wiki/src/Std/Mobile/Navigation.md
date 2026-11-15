---
type: module
path: "@root/lib/Std/Mobile/Navigation.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, navigation]
aliases: [Std Mobile Navigation]
---

# Std Mobile Navigation

## Purpose and interface

Route state for [[Native iOS Navigation]] uses the root-preserving
`Std.Ui.Navigation.Stack[Route]`. A route contains `id: UInt32`, `title: Str`
and `body: View`. A `Pop` names the previous top and surviving destination.

- `validate(&Stack[Route]) -> Result[(), NavigationError]` admits a stack with
  distinct instance IDs and reports the first `DuplicateRoute(id)` in root-to-top order.
- `afterPop(&Stack[Route], Pop) -> Option[Stack[Route]]` returns the trimmed
  stack when the previous top matches and the destination appears below it.
  The input stack must have passed validation.

## Invariants

The root survives every accepted pop. A destination can be the root or an
earlier pushed route. A pop to the current route, to a missing route, or from
an older top produces `None`. The input stack remains available to the app.
Route IDs are application instance identities independent of host node IDs.

## Negative logic

No platform calls, event delivery or controller handles. The host reports
completed pops and the reducer decides whether they still apply.

## Dependencies and consumers

Depends on [[Std Ui Navigation]] and [[Std Mobile View]]. Exercised by
[[Uses Mobile View]]. The next navigation partition connects this module to
the native presentation and event bridge.

## Resolved Grill Log

- **Q:** Why return an optional stack? **A:** A stale or invalid completion
  must be distinguishable from an accepted pop, including a pop to root.
- **Q:** Where are duplicate IDs diagnosed? **A:** A single traversal in
  presentation order names the first duplicate before the presentation is
  serialized. The reducer operates on validated state.

## Referenced by

[[src/Std/_MOC]] · [[Native iOS Navigation]] · [[Native iOS Navigation Delivery]]
