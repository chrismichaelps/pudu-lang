---
type: module
path: "@root/lib/Std/Mobile/Navigation.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui, navigation]
aliases: [Std Mobile Navigation]
---

# Std Mobile Navigation

## Purpose and interface

Pure description of a native navigation stack and one page sheet. The program owns the routes. Each route is a page with an id, a title and a body; the sheet is one more body with its own id. The platform controls rendering, the back gesture and the sheet's dismissal, and reports completed user input back as events. `mount` builds every body and shows the stack; `update` reconciles a changed presentation and appends one NAVIGATE only when the platform's stack must change. Bodies are built and reconciled with [[Std Mobile View]]'s `body`, `rebody` and `unmount`. Instructions are spelled by [[Std Mobile Stream]]; the `Popped` and `Dismissed` events are values of [[Std Mobile View]]'s `Event`, decoded by [[Std Mobile Events]].

Exports:
- `type Route = { id: UInt32, title: Str, body: View.View }`: one route instance. The id is application-supplied and unique within a presentation.
- `type Sheet = { id: UInt32, body: View.View }`: the page sheet's instance, with its own id and body.
- `type Presentation = { root: Route, pushed: Array[Route], sheet: Option[Sheet] }`: the root route, the routes pushed over it in order, and at most one sheet. The host refuses a presentation that repeats an id.
- `type Page = { id: UInt32, title: Str, body: View.Shown }`: a route as mounted, with its body's tree.
- `type Shown = { pages: Array[(UInt32, UInt32, Str)], sheet: Option[(UInt32, UInt32)] }`: the navigation the platform shows. Each page is its route id, body node and title, root first; the sheet is its id and body node.
- `type Mounted = { pages: Array[Page], sheet: Option[Page], next: UInt32, free: Array[UInt32], shown: Shown }`: the mounted pages and sheet, the next fresh id, the freed ids, and the navigation the platform shows, including user pops and dismissals folded in by `observe`.
- `mount(presentation: &Presentation) -> (Mounted, Bytes)`: `update` from an empty stack. It builds every page body and the sheet body, and its stream ends in one NAVIGATE.
- `update(mounted: &Mounted, presentation: &Presentation) -> (Mounted, Bytes)`: the mounted navigation after `presentation` is shown, and the stream that moves the screen there.
- `observe(mounted: Mounted, event: &View.Event) -> Mounted`: folds a user report into `shown`. `Popped(top, destination)` trims `shown` after the destination when `kept` accepts the report. `Dismissed(id)` clears `shown`'s sheet when its id is `id`. Any other event, or a stale report, returns `mounted` unchanged.
- `kept(stack: &Array[UInt32], top: UInt32, destination: UInt32) -> Option[Int]`: how many routes of the stack (route ids, root first) survive a reported pop from `top` to `destination`. It answers None when `top` is not the current top, or `destination` is not below it.

## Invariants

- Pure: the module declares no foreign function. Platform calls live in [[Std Mobile Host]].
- Pages in the common prefix keep their page only when the route at the same position has the same id. The common prefix is matched by position and id, so a route replaced or removed ends its instance.
- A page in the common prefix reconciles its body with `rebody`. A later mounted page is dropped with `unmount`, and each later wanted route is built with `body`.
- The sheet keeps its body only when its id is unchanged. A sheet that is dropped, replaced or removed is unmounted. The sheet's page title is empty.
- One NAVIGATE is appended only when the resulting `shown` differs from the mounted `shown`. An ordinary body edit does not resend it, and an unchanged commit produces an empty stream.
- `observe` changes only `shown`. The pages and the sheet's body are not changed by a report.
- After a reported pop is folded in, `shown` matches what the platform shows. An app that applies the pop sends no NAVIGATE on its next update. An app that keeps its old stack sends the whole stack again.
- `kept` never answers a count below 1 or above the stack's length minus one.

## Negative Logic

- No platform call and no I/O. The host applies the stream.
- No validation of route ids. A presentation that repeats an id is refused by the host before any controller changes.
- No echo of a programmatic change. A change the program made is already in `shown` after its update, so the platform's completion reports nothing.
- No pop or dismissal is reported for a stack or sheet the program has not shown.
- No route is built outside the presentation.

## Dependencies and consumers

Depends on [[Std Mobile View]] for `View`, `Event`, `Shown`, `body`, `rebody` and `unmount`, and on [[Std Mobile Stream]] for NAVIGATE. Consumers: the application's presenter, which calls `mount` and `update` for each commit and `observe` for each completion. The host for the stack is [[pudu_ios_navigation.h]]. The example is [[Native Pages Example]], and its fixture is [[Uses Mobile Navigation]]. The architecture is [[Native iOS Navigation]].

## Resolved Grill Log

- **Q:** Who owns route state? **A:** The program; the platform reports completed input and shows the desired state.
- **Q:** Why fold reports into what was shown? **A:** So an app that refuses a pop resends its stack, and one that accepts it sends nothing, with no echo.
- **Q:** Why match by position and id? **A:** The same route at the same place keeps its controller; replacing or removing one ends that instance.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Events]] · [[Std Mobile Stream]] · [[Native iOS Navigation]] · [[pudu_ios_navigation.h]] · [[Native iOS Navigation Delivery]]
