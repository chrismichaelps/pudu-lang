---
type: module
path: "@root/lib/Std/Mobile/Navigation.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui, navigation, tabs]
aliases: [Std Mobile Navigation]
---

# Std Mobile Navigation

## Purpose and interface

Pure description of native navigation: one page stack with at most one page sheet, or a tab bar whose tabs each hold a stack, with at most one sheet over the bar. The program owns the routes and the selection. Each route is a page with an id, a title and a body; the sheet is one more body with its own id. The platform controls rendering, the back gesture, tab picks and the sheet's dismissal, and reports completed user input back as events. `mount` and `update` serve the single stack and emit NAVIGATE. `mountTabs`, `updateTabs` and `observeTabs` serve the tab bar and emit TABS. Bodies are built and reconciled with [[Std Mobile View]]'s `body`, `rebody` and `unmount`. Instructions are spelled by [[Std Mobile Stream]]; the `Popped`, `Dismissed` and `Selected` events are values of [[Std Mobile View]]'s `Event`, decoded by [[Std Mobile Events]]. The single stack and the tabs share their private stack, sheeted and listed helpers, so a route is reconciled the same way in both.

Exports:
- `type Route = { id: UInt32, title: Str, body: View.View }`: one route instance. The id is application-supplied and unique within a presentation.
- `type Sheet = { id: UInt32, body: View.View }`: the page sheet's instance, with its own id and body.
- `type Presentation = { root: Route, pushed: Array[Route], sheet: Option[Sheet] }`: the root route, the routes pushed over it in order, and at most one sheet. The host refuses a presentation that repeats an id.
- `type Page = { id: UInt32, title: Str, body: View.Shown }`: a route as mounted, with its body's tree.
- `type Shown = { pages: Array[(UInt32, UInt32, Str)], sheet: Option[(UInt32, UInt32)] }`: the navigation the platform shows. Each page is its route id, body node and title, root first; the sheet is its id and body node.
- `type Mounted = { pages: Array[Page], sheet: Option[Page], next: UInt32, free: Array[UInt32], shown: Shown }`: the mounted pages and sheet, the next fresh id, the freed ids, and the navigation the platform shows, including user pops and dismissals folded in by `observe`.
- `type Tab = { id: UInt32, title: Str, symbol: Str, root: Route, pushed: Array[Route] }`: one tab, with its id, the title and system symbol its bar item shows, and its own stack, root first. Route ids are unique across every tab.
- `type Tabbed = { tabs: Array[Tab], selected: UInt32, sheet: Option[Sheet] }`: the tabs in bar order, the selected tab's id, and at most one sheet over the bar.
- `type TabShown = { id: UInt32, title: Str, symbol: Str, pages: Array[(UInt32, UInt32, Str)] }`: a tab the platform shows, with each page's route id, body node and title, root first.
- `type TabsShown = { tabs: Array[TabShown], selected: UInt32, sheet: Option[(UInt32, UInt32)] }`: the tabs the platform shows, the selected tab and the sheet.
- `type TabsMounted = { stacks: Array[(UInt32, Array[Page])], sheet: Option[Page], next: UInt32, free: Array[UInt32], shown: TabsShown }`: the mounted pages of each tab by tab id, the sheet, the next fresh id, the freed ids, and what the platform shows, with picks, pops and dismissals folded in by `observeTabs`.
- `mount(presentation: &Presentation) -> (Mounted, Bytes)`: `update` from an empty stack. It builds every page body and the sheet body, and its stream ends in one NAVIGATE.
- `update(mounted: &Mounted, presentation: &Presentation) -> (Mounted, Bytes)`: the mounted navigation after `presentation` is shown, and the stream that moves the screen there.
- `observe(mounted: Mounted, event: &View.Event) -> Mounted`: folds a user report into `shown`. `Popped(top, destination)` trims `shown` after the destination when `kept` accepts the report. `Dismissed(id)` clears `shown`'s sheet when its id is `id`. Any other event, or a stale report, returns `mounted` unchanged.
- `mountTabs(tabbed: &Tabbed) -> (TabsMounted, Bytes)`: `updateTabs` from an empty bar. Its stream ends in one TABS.
- `updateTabs(mounted: &TabsMounted, tabbed: &Tabbed) -> (TabsMounted, Bytes)`: the mounted tabs after `tabbed` is shown, and the stream that shows them. A tab no longer presented has its pages ended. TABS is written only when the bar differs from what the platform shows.
- `observeTabs(mounted: TabsMounted, event: &View.Event) -> TabsMounted`: folds a person's tab pick into `shown.selected` when the picked id is a shown tab, a completed pop into the tab that holds the popped route, and a sheet dismissal into `shown`. Any other event, or a stale report, returns `mounted` unchanged.
- `kept(ids: &Array[UInt32], top: UInt32, destination: UInt32) -> Option[Int]`: how many routes of the stack (route ids, root first) survive a reported pop from `top` to `destination`. It answers None when `top` is not the current top, or `destination` is not below it.

Private helpers, shared by the single stack and the tabs: `stack` reconciles a list of routes against held pages, `sheeted` reconciles the sheet, `listed` names each page's route id, body node and title, `common` counts the leading pages that keep their place, `bodied` builds or reconciles one body, `dropped` unmounts one, and `sheetShown` names the sheet's id and body node. Tab helpers are `presents` and `stackOf`.

## Invariants

- Pure: the module declares no foreign function. Platform calls live in [[Std Mobile Host]].
- Pages in the common prefix keep their page only when the route at the same position has the same id. The common prefix is matched by position and id, so a route replaced or removed ends its instance.
- A page in the common prefix reconciles its body with `rebody`. A later mounted page is dropped with `unmount`, and each later wanted route is built with `body`.
- The sheet keeps its body only when its id is unchanged. A sheet that is dropped, replaced or removed is unmounted. The sheet's page title is empty.
- One NAVIGATE is appended only when the resulting `shown` differs from the mounted `shown`. One TABS is appended only when the resulting bar differs from the mounted bar. An ordinary body edit does not resend either, and an unchanged commit produces an empty stream.
- A tab's stack is reconciled against the stack its id held before, so a tab keeps its pages across picks.
- `observe` and `observeTabs` change only `shown`. The pages and the sheet's body are not changed by a report.
- `observeTabs` accepts a pick only for a tab the platform shows, so a pick of an unknown id is ignored and the next update resends the bar.
- After a reported pop or dismissal is folded in, `shown` matches what the platform shows. An app that applies the report sends nothing on its next update. An app that keeps its old state sends the whole state again.
- `kept` never answers a count below 1 or above the stack's length minus one.

## Negative Logic

- No platform call and no I/O. The host applies the stream.
- No validation of route ids. A presentation that repeats an id is refused by the host before any controller changes.
- No echo of a programmatic change. A change the program made is already in `shown` after its update, so the platform's completion reports nothing.
- No pop, pick or dismissal is reported for a stack, tab or sheet the program has not shown.
- No route is built outside the presentation or the tabbed bar.
- No single-stack and tab state at once. A NAVIGATE replaces the tabs, and a TABS replaces the single stack; the host closes the one it replaces.

## Dependencies and consumers

Depends on [[Std Mobile View]] for `View`, `Event`, `Shown`, `body`, `rebody` and `unmount`, and on [[Std Mobile Stream]] for NAVIGATE and TABS. Consumers: the application's presenter, which calls `mount` or `mountTabs` for the first commit, `update` or `updateTabs` for each later commit, and `observe` or `observeTabs` for each completion. The iOS hosts are [[pudu-ios-navigation]] and [[pudu-ios-tabs]]; the Android hosts are [[PuduNavigator]] and [[PuduTabs]]. The examples are [[Native Pages Example]] and [[Tabs Example]], and their fixtures are [[Uses Mobile Navigation]] and [[Uses Mobile Tabs]]. The architecture is [[Native iOS Navigation]].

## Resolved Grill Log

- **Q:** Who owns route state? **A:** The program; the platform reports completed input and shows the desired state.
- **Q:** Why fold reports into what was shown? **A:** So an app that refuses a pop resends its stack, and one that accepts it sends nothing, with no echo.
- **Q:** Why match by position and id? **A:** The same route at the same place keeps its controller; replacing or removing one ends that instance.
- **Q:** Why one shared helper set for the stack and the tabs? **A:** A tab is a stack with an id. Reconciling a tab's routes with the single stack's helpers keeps one rule for pages, so the two cannot drift apart.
- **Q:** Why does a tab pick count only for a shown tab? **A:** The platform reports the tabs it shows. A pick of an id outside the bar is stale, and it must not change the selection the program holds.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Events]] · [[Std Mobile Stream]] · [[Native iOS Navigation]] · [[pudu-ios-navigation]] · [[pudu-ios-tabs]] · [[PuduTabs]] · [[Tabs Example]] · [[Uses Mobile Tabs]] · [[Native iOS Navigation Delivery]] · [[Native Tabs]]
