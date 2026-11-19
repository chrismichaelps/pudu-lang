---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_navigation.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, navigation, objective-c]
aliases: [pudu_ios_navigation.h]
---

# pudu_ios_navigation.h

## Purpose and interface

The native page stack and page sheet of a Pudu Native application on iOS. The program owns which routes exist; a NAVIGATE names them root first, each with its body node and title, then the sheet. UIKit draws the bars, the back affordances and the transitions. The header is included once by [[iOS Host Adapter]], which dispatches NAVIGATE (36) to it. Its model is [[Std Mobile Navigation]]; its stream is [[Std Mobile Stream]]; the events it queues are decoded by [[Std Mobile Events]].

Entry points used by the adapter:
- `pudu_navigation_read(reader)`: reads one NAVIGATE whole and answers its routes and sheet, or refuses the stream. It takes no callback.
- `pudu_navigation_body(reader, &fills)`: reads one route's or the sheet's body node, using `pudu_node_id` and `pudu_node_scrolls` from [[pudu_ios_nodes.h]], and reports whether that body fills its page.
- `pudu_navigation_show(root, desired)`: installs the stack over the root controller on first use, then shows `desired`.
- `pudu_navigation_top()`: the body on top of the screen, the sheet's when one is shown, otherwise the top page's.
- `pudu_test_navigation(done)`: the self-test of `PUDU_UI_NAVIGATION_TEST`.

Types:
- `PuduPage`: a `UIViewController` for one route or the sheet. It has the route id, the body view and the layout guide of its area. `show:fills:` places a body under the platform's bars with the screen's safe-area and docked-keyboard policy.
- `PuduNavigator`: the navigator, a delegate of the navigation controller and of the sheet's presentation. It holds the stack, the pages by route id, the accepted stack of route ids, the sheet, the presenting flag, and the pending presentation.

## Behavior

- `pudu_navigation_read` reads the count, then each route's id, body node and title, then the sheet flag and, for a sheet, its id and body node. It refuses, as a stream defect, a count of zero, two routes with one id, a sheet flag above 1, and a sheet that shares a route's id. Each body is read by `pudu_navigation_body`, which sets `fills` from `pudu_node_scrolls` for scroll and list kinds, so those bodies fill the page and the others are centered.
- The read happens before any controller changes. The shown root is removed only after a valid NAVIGATE is read, and the stack is then installed.
- The first NAVIGATE installs a `UINavigationController` as a child of the root controller, sized to the root view and covering the surface. Its delegate is the navigator.
- `want:` unqueues the unread POPPED and DISMISSED events, so a newer NAVIGATE supersedes earlier reports the program has not read. It then makes the new presentation pending and settles it.
- `settle` does nothing while a presentation is pending and a sheet transition is in flight. While a navigation transition is in flight, it waits for the transition's completion and settles again on the main queue. The newest pending presentation is the one applied, so an older update is never shown after a newer one.
- Settling applies the desired routes: each route's page is reused by route id, its body is shown, and its title sets the navigation item. The accepted stack is set to the new route ids before the platform animates the change, so the completion compares equal and reports nothing.
- `navigationController:didShowViewController:animated:` compares the final stack with the accepted stack. When nothing is pending and the final stack is a strict prefix of the accepted one, the host queues POPPED with the previous top as its tag and the surviving top as its detail. Any other completion queues nothing; a cancelled swipe leaves the stack equal and reports nothing.
- The sheet is a page-sheet presentation of its own `PuduPage`. Its presentation controller's delegate is the navigator. A same-id sheet is updated in place. A changed sheet dismisses the current one, if it is presented, and presents the replacement once that dismissal finishes. A removed sheet is dismissed and nothing is queued.
- `presentationControllerDidDismiss:` clears the alert presenter if it was the dismissed sheet. For the current sheet only, it sets the sheet to nil, queues DISMISSED with the route id as its tag, and settles. A report about an earlier sheet is ignored, so it cannot close its replacement.
- While a sheet is shown, alerts are presented from it, and otherwise from the root.
- Self-test `pudu_test_navigation` runs on a 0.1-second timer for at most 30 seconds, and waits for each step to settle. It taps Open on the Pages example and checks for two stack entries, then pops once and checks for the label Pops: 1. It shows the sheet, dismisses it, and calls the dismissal handler, then checks for Dismissals: 1. It shows the sheet again, taps its Close button, and checks that no dismissal is counted. It prints `PUDU_NAV pushed`, `PUDU_NAV popped once`, `PUDU_NAV sheet shown`, `PUDU_NAV sheet dismissed once` and `PUDU_NAV sheet closed without echo`, then asks the program to stop. On timeout it prints the step to standard error and asks the program to stop.
- Tabs (#977) replace the stack. TABS (54) is handled by [[pudu-ios-tabs]]: a TABS detaches the single stack, and a NAVIGATE closes the tab bar. The two never show at once.

## Negative Logic

- No application logic. The host does not decide which routes exist, which route is on top, or whether a sheet is open.
- No event for a gesture that has begun but not completed. Only the final stack after completion counts.
- No event for a programmatic push, pop or dismissal. The accepted stack is set before the platform animates, so the completion compares equal.
- No event for a pending presentation's own transition; the newer update takes precedence over the user's transition, whose completion is not reported.
- No controller is dropped by a reported pop. The pages map keeps the last presentation's controllers until the next presentation replaces it.
- No repair of a refused NAVIGATE. The defect ends the process with a message naming it, as the other host headers do.

## Dependencies and consumers

Included by [[iOS Host Adapter]]. Uses [[iOS Host Layout]] for the available area and root placement, [[iOS Host Events]] for the queue and `pudu_unqueue`, [[iOS Host Controls]] and [[iOS Host Feedback]] for the page content and alerts, [[iOS Host Stream]] for the reader, and [[pudu_ios_nodes.h]] for the node table and the body reads. Its stream is written by [[Std Mobile Stream]] and its events are decoded by [[Std Mobile Events]]. The application shown in its self-test is [[Native Pages Example]]. Architecture: [[Native iOS Navigation]].

## Resolved Grill Log

- **Q:** Report a back when the swipe begins? **A:** No; only the final stack after completion counts, so a cancelled gesture reports nothing.
- **Q:** How are programmatic updates kept from echoing? **A:** The accepted stack is updated before the platform animates, so its completion compares equal.
- **Q:** Why keep only the newest pending update during a transition? **A:** The newest desired state is the one the program holds; applying an older one after it would show a stack the program no longer wants.
- **Q:** Why does a new NAVIGATE drop unread pop and dismissal reports? **A:** Those reports were made against the presentation it replaces. The program sees the state the new NAVIGATE sets, so a report about the old state would act on a stack it no longer describes.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Navigation]] · [[Std Mobile Events]] · [[Native iOS Navigation]] · [[Native iOS Navigation Delivery]]
