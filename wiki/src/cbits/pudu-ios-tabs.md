---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_tabs.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, navigation, tabs, objective-c]
aliases: [iOS Host Tabs, pudu-ios-tabs]
---

# pudu-ios-tabs

## Purpose and interface

The tab bar of a Pudu Native application on iOS: one navigation stack per tab under a `UITabBarController`, each tab's system symbol as its bar item image, and at most one page sheet over the bar. The program owns the tabs, each tab's routes and the selection. A person's tab pick is applied at once and reported as SELECTED. A pop inside a tab is reported as POPPED, under the same rule as the single stack of [[pudu-ios-navigation]]. TABS (54) replaces a single-stack navigation, and NAVIGATE (36) replaces the tabs. The header is included once by [[iOS Host Adapter]], which dispatches TABS to it. Its model is [[Std Mobile Navigation]]; its stream is [[Std Mobile Stream]]; its reports are decoded by [[Std Mobile Events]] and queued through [[iOS Host Events]].

Entry points used by the adapter:
- `pudu_tabs_read(reader)`: reads one TABS whole and answers its tabs, selection and sheet, or refuses the stream. It takes no callback.
- `pudu_tabs_show(root, desired)`: installs the tab bar over the root controller on first use, removing a single stack if one is shown, then hands `desired` to the bar.
- `pudu_tabs_top()`: the body on top of the screen, the sheet's when one is shown, otherwise the selected tab's top page's.
- `pudu_tabs_close()`: ends the tabs, for a NAVIGATE or a ROOT that replaces them.
- `pudu_test_tabs(done)`: the self-test of `PUDU_UI_TABS_TEST`.

Types:
- `PuduTabStack`: one tab's stack. It holds the tab id, its `UINavigationController`, its pages by route id, and the route ids last accepted. It is the navigation delegate of its stack.
- `PuduTabs`: the tab bar. It holds the root, the `UITabBarController`, the stacks by tab id, the pending presentation, the sheet, and a presenting flag. It is the delegate of the bar and of the sheet's presentation.

## Behavior

- `pudu_tabs_read` reads the tab count, then for each tab its id, title, symbol and page count, then for each page its route id, body node and title. It then reads the selected tab id and the sheet flag, and for a sheet its route id and body node. It refuses, as a stream defect, the cases listed under Negative Logic and the refusal table below. The whole stream is read before any controller changes.
- Refusals of TABS, each a stream defect:
  - a count of zero, `showed a tab bar without tabs, count`;
  - two tabs with one id, `showed two tabs with id`;
  - a tab with no root route, `showed a tab without a root route, tab`;
  - two routes with one id across all tabs, `showed two routes with id`;
  - a selected id that names no tab, `selected a tab that is not shown:`;
  - a sheet flag above 1, `marked a sheet with`;
  - a sheet whose route id is a tab route's id, `showed a sheet sharing a route's id`.
- The first TABS installs a `UITabBarController` as a child of the root controller, sized to the root view and covering the surface. A single stack shown before it is detached, and the navigator is cleared.
- `want:` unqueues the unread POPPED, DISMISSED and SELECTED events, so a newer TABS supersedes earlier reports the program has not read. It then makes the new presentation pending and settles it.
- `settle` does nothing while a presentation is pending and a sheet is in flight. It waits, and settles again on the main queue, while any tab's stack has a transition in flight. The newest pending presentation is the one applied.
- Settling applies each tab in bar order. Each tab's stack reuses its pages by route id, shows each body, sets each page's title, and sets the accepted route ids before the platform animates, so the completion compares equal. The bar item shows the tab's title and the system image named by the symbol, through `UIImage systemImageNamed`. The selected index is set on the bar without animation.
- `tabBarController:didSelectViewController:` queues SELECTED with the tab's id as its tag. A programmatic selection does not reach this delegate call, so it reports nothing.
- `UINavigationControllerDelegate` on each `PuduTabStack`: when the final stack is a strict prefix of its accepted route ids and not empty, it queues POPPED with the tab's previous top as the tag and the surviving top as the detail. Any other completion reports nothing.
- The sheet is a page-sheet presentation over the bar. A same-id sheet is updated in place. A changed sheet dismisses the current one, if presented, and presents the replacement once that dismissal finishes. A removed sheet is dismissed and nothing is queued.
- `presentationControllerDidDismiss:` clears the alert presenter if it was the dismissed sheet. For the current sheet only, it sets the sheet to nil, queues DISMISSED with the route id as its tag, and settles. A report about an earlier sheet is ignored.
- Self-test `pudu_test_tabs` runs on a 0.1-second timer for at most 30 seconds, and waits for each step to settle. It selects the second tab and checks for the label Selected: 2, then selects the first tab and checks for Selected: 1. It taps Open, checks for two stack entries, pops once and checks for Pops: 1. It taps Show sheet, dismisses the sheet, and checks for Dismissals: 1. It prints `PUDU_TABS picked`, `PUDU_TABS pushed`, `PUDU_TABS popped once` and `PUDU_TABS sheet dismissed once`. On timeout it prints the step to standard error and asks the program to stop.

## Invariants

- TABS is read whole before any controller changes. A refused TABS leaves the screen as it was.
- Route ids are unique across every tab, so one POPPED or DISMISSED names one page.
- A tab's accepted route ids always equal its stack's route ids after settling, so a programmatic change reports nothing.
- The tab bar, its stacks and the sheet are changed only from the main thread.

## Negative Logic

- No event for a programmatic selection, push, pop or dismissal.
- No retry of a refused TABS. The defect ends the process with a message naming it.
- No choice of tab by the host. The program's selection is shown; only a person's tap changes it, and that tap is reported.
- No outcome for a gesture still in flight. Only the completed stack counts.
- No symbol check. An unknown system symbol name is left to the platform's image lookup, which yields no image.

## Dependencies and consumers

Depends on UIKit (`UITabBarController`, `UINavigationController`, the bar item, the page sheet presentation and `UIImage systemImageNamed`), [[iOS Host Events]] for the queue and `pudu_unqueue`, [[pudu-ios-navigation]] for the page class and the route id helper, [[pudu-ios-nodes.h]] for the node table and body reads, [[iOS Host Stream]] for the reader, and [[pudu-ios-kinds]] for the instruction table. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile Navigation]], [[Std Mobile Stream]] and [[Std Mobile Events]]. The application shown in its self-test is [[Tabs Example]]. Android counterpart: [[PuduTabs]] and [[pudu-android-routes]].

## Resolved Grill Log

- **Q:** Why one navigation controller per tab rather than one stack that changes on a pick? **A:** Each tab keeps its own pages, so a pick returns the person to the page they left. One shared stack would lose the tab's place on every switch.
- **Q:** Why report a pick but not a programmatic selection? **A:** A pick is the person's input, which the program must see to keep its model. A selection the program made is already in its model, so a report would echo it back.
- **Q:** Why does a pop need the strict-prefix rule? **A:** A pop is the platform removing the top page. A cancelled swipe leaves the stack equal to the accepted one, so it reports nothing, the same as the single stack.
- **Q:** Why does the sheet cover the bar rather than one tab? **A:** A sheet is a decision the whole application waits on, not a page of one tab. Over the bar it is reached from any tab, and it has one id the program can dismiss.
- **Q:** Why does TABS replace the single stack and NAVIGATE replace the tabs? **A:** Both describe the whole screen. Keeping one of them at a time means one owner for the root's child controller, so no two navigators fight over it.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[pudu-ios-navigation]] · [[pudu-ios-system]] · [[Std Mobile Navigation]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Tabs Example]] · [[Uses Mobile Tabs]] · [[Native Tabs]] · [[NATIVE-MOBILE]]
