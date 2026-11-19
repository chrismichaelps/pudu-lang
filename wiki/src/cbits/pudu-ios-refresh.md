---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_refresh.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, refresh, objective-c]
aliases: [iOS Host Refresh, pudu_ios_refresh.h]
---

# pudu_ios_refresh.h

## Purpose and interface

Private refresh implementation of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the pull-to-refresh control of a scroll or list node, the report of each user pull, and the stop of an unanswered pull. It implements the REFRESH (37) instruction of [[Std Mobile Stream]] and queues the REFRESHED (16) event of [[Std Mobile Events]].

The header provides:
- `PuduRefresh`: a `UIRefreshControl` subclass. It holds the tag its pulls report, the program's wanted state, and whether a pull is unanswered. Its `pull` method marks the pull unanswered, records the control in the set of unanswered pulls, and queues REFRESHED with the control's tag.
- `pudu_do_refresh`: the REFRESH handler. It reads the node, the reported tag and the flag, refuses a node that does not scroll and a flag other than 0 or 1, and then sets the control.
- `pudu_refresh_settle`: the hook that ends unanswered pulls. It is installed as `pudu_before_wait` in [[iOS Host Events]] the first time a refresh control is set.

## Behavior

- `pudu_do_refresh` reads the node id with `pudu_node_id` from [[pudu_ios_nodes.h]], then the reported tag, then the flag. A node for which `pudu_node_scrolls` is false is refused with the stream defect `refreshed a node that does not scroll:` followed by the node id. A flag above 1 is refused with `set refreshing to` followed by the value. Both checks run before the control changes.
- The control is the refresh control of the node's scroll view. It is created on first use, with a target that calls its `pull` method on the value-changed event, and the scroll view is made to bounce vertically. A later REFRESH on the same node reuses the control and sets its tag and wanted state.
- The wanted state is the flag. A flag of 1 begins refreshing when the control is not already refreshing. A flag of 0 ends refreshing only when no pull is unanswered; an unanswered pull keeps the indicator until the hook below runs.
- A user pull sets `pulled`, adds the control to the set of unanswered pulls, and queues REFRESHED with the control's reported tag.
- `pudu_refresh_settle` runs before each wait. For each unanswered pull, it checks whether a REFRESHED event with that control's reported tag is still queued. When none is queued, the program has read the report. The hook clears the pull and removes the control from the set. If the wanted state is still false and the indicator is showing, it ends refreshing. A pull the program answered with 1 keeps refreshing.
- The self-test `pudu_test_refresh` runs on a 0.1-second timer for at most 20 seconds, against the Refresh example [[Native Refresh Example]]. It checks four steps, each printed once in order:
  1. When the insets are reported, it prints `PUDU_REFRESH insets reported` and starts a pull as the user's gesture would.
  2. When the indicator is refreshing and `Pulls: 1` is on screen, it prints `PUDU_REFRESH answered pull refreshing` and taps Done.
  3. When the indicator has stopped, it prints `PUDU_REFRESH finished by the program` and starts a second pull.
  4. When the indicator has stopped and `Pulls: 2` is on screen, it prints `PUDU_REFRESH unanswered pull stopped`, and asks the program to stop.
- On timeout the self-test writes `pudu: refresh test timed out at step` followed by the step number to standard error, and asks the program to stop.

## Invariants

- The program's wanted state is the only state that keeps an answered pull refreshing. The hook ends a pull only when the program has read its report and did not ask to refresh.
- A REFRESHED event is queued once for each user pull, carrying the reported tag of its control.
- The control, the set of unanswered pulls and the hook are touched only on the thread that runs the program, as every call of [[iOS Host Adapter]] is.

## Negative Logic

- No refreshing state is kept by the platform on the program's behalf. A pull reports; the program decides.
- No stop while the pull's REFRESHED report is still queued. The program has not yet read it.
- No REFRESHED event for a refresh the program starts. Only user pulls report.
- No refusal of a node kind other than through `pudu_do_refresh`; the refusal of a non-scrolling node is made by this header's handler, not by the dispatcher.

## Dependencies and consumers

Depends on UIKit for `UIRefreshControl` and the scroll view, on [[pudu_ios_nodes.h]] for `pudu_node_id`, `pudu_node_scrolls` and the node table, on [[iOS Host Events]] for the queue and the pre-wait hook, on [[Std Mobile Stream]] for the REFRESH spelling and on [[Std Mobile Events]] for REFRESHED. Included by [[iOS Host Adapter]], which dispatches REFRESH to `pudu_do_refresh`. The program side is [[Std Mobile View]], whose `Refreshing` wrapper writes REFRESH for its node.

## Resolved Grill Log

- **Q:** Why stop an unanswered pull at the next wait? **A:** That is the first moment the program has handled the report; if it did not ask to refresh, nothing else will ever end the indicator.
- **Q:** Why does a flag of 0 not end a pull that is still unanswered? **A:** The program has not yet read the report that started it. Ending the indicator at once would hide the pull from the program before it can answer, so the hook ends it at the next wait instead.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[iOS Host Events]] · [[pudu_ios_nodes.h]] · [[Std Mobile Stream]] · [[Native iOS Refresh Delivery]] · [[Native Refresh Example]]
