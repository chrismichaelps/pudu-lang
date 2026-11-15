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

- `mount(&Stack[Route]) -> Result[(MountedStack, Bytes), NavigationError]`
  validates and builds every body, then emits one ordered navigation snapshot.
- `update(&MountedStack, &Stack[Route], reassert: Bool)` validates and returns
  the new mounted state and commit. The common route prefix retains its bodies
  as far as the existing view reconciler can update them in place. A change to
  route identity, body root ID, or title emits a new snapshot.
- `reassert` emits the snapshot even if the route descriptors are unchanged.
  It acknowledges a native pop that the app declines.

## Invariants

Snapshots follow the body builds and precede retirement of old roots. IDs from
retired roots are available only to later commits. In-place edits can emit body
instructions without a navigation snapshot. A duplicate-ID diagnostic produces
no commit.

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

## Page sheet

`mountPresentation(stack, sheet)` and `updatePresentation(held, stack, sheet, reassert)`
reconcile navigation and a single optional `Sheet{id, body}` with the same node
allocator. A sheet ID colliding with a route is refused before producing a commit.
A sheet with the same ID can reconcile its body in place. Write SHEET before retiring
a removed or replaced body. `afterDismissal` clears only the current instance.
The stack-only API describes a presentation without a sheet.

A resolved Grill Log decision keeps the sheet with the stack allocator so its IDs
cannot collide with a mounted page and it can share the existing body reconciler.

## Resolved Grill Log

- **Q:** Why return an optional stack? **A:** A stale or invalid completion
  must be distinguishable from an accepted pop, including a pop to root.
- **Q:** Where are duplicate IDs diagnosed? **A:** A single traversal in
  presentation order names the first duplicate before the presentation is
  serialized. The reducer operates on validated state.

- **Q:** When does a body replacement retire the old tree? **A:** After the new
  snapshot. This prevents the host from observing a route descriptor that points
  at a node already retired in the same commit.

## Referenced by

[[src/Std/_MOC]] · [[Native iOS Navigation]] · [[Native iOS Navigation Delivery]]
