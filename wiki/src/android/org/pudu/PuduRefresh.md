---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduRefresh.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, refresh, touch, overlay]
aliases: [PuduRefresh, Native Android Refresh]
---

# PuduRefresh

## Purpose and interface

Pull to refresh for a scroll or list of the Android host, built from platform views. A pull is a drag that starts with the content at its top and travels 72 dp. It reports REFRESHED with the tag the program gave the node. The program's flag decides whether the indicator refreshes. The class is called from `PuduBridge.refresh` for REFRESH and from `PuduBridge.settleRefresh` for the settle hook; both run on the main thread. [[pudu_android_routes.h]] refuses a node that does not scroll and a flag other than 0 or 1 before this class is called.

```java
final class PuduRefresh implements View.OnTouchListener
static final int REFRESHED = 16;
static void set(ViewGroup view, int reported, boolean on)
static void settle(int[] queued)
```

## Behavior

- `set` attaches the listener to the view once, keyed in a weak map by view, and updates the tag and the wanted state on each call. A flag of 1 shows the indicator. A flag of 0 hides it only when no pull is unanswered.
- The listener never consumes a touch: it returns false for every event, so the scroll keeps all touches. It watches only.
- On ACTION_DOWN it records whether the view cannot scroll up (`canScrollVertically(-1)` is false) and the touch's y. On ACTION_UP, a tracked drag that is not already showing and travels at least 72 dp, converted by density, counts as a pull. ACTION_CANCEL clears the tracking.
- A pull marks the record pulled, shows the indicator, and sends `PuduBridge.event(REFRESHED, tag, null, 0, null)`.
- The indicator is a 40 dp indeterminate `ProgressBar`. It is added to the view's overlay at the top center, 8 dp down, measured and laid out explicitly. The overlay keeps the content's layout unchanged.
- `settle` posts to the main thread. For each record that is pulled, it checks whether the record's tag is absent from the queued tags. An absent tag means the program has read the report. The record is then no longer pulled, and the indicator is hidden when the program did not ask to refresh.
- A pull the program answers with a flag of 1 keeps refreshing until the flag is 0 and the pull has been read.

## Invariants

- The indicator is shown only through the overlay, so a refresh never changes the layout of the list.
- A REFRESHED event is sent once per pull. A drag that begins while the indicator shows is not a pull.
- A pull is ended only after the program's queue has been read without its tag; it is never ended by the platform alone.

## Negative Logic

- No touch consumption. A scroll or tap inside the list behaves as it would without refresh.
- No refreshing state kept on the platform's behalf. A pull reports; the program's flag decides whether the indicator stays.
- No report for a refresh the program starts. The program's flag alone changes the indicator.

## Dependencies and consumers

Depends on `MotionEvent`, `View.OnTouchListener`, `ProgressBar` and the view overlay, on [[PuduBridge]] for the main-thread handler and `event`, and on the density of the target's resources. Called through [[pudu_android_routes.h]]: `pudu_do_refresh` calls `PuduBridge.refresh` and installs the settle hook. The iOS counterpart is [[pudu_ios_refresh.h]], whose `UIRefreshControl` gives the same report and settle rules.

## Resolved Grill Log

- **Q:** Why does the listener return false instead of taking the drag? **A:** A consumed touch would stop the scroll from following the finger and would break taps in the list. Watching the drag leaves the scroll and the touch targets as they are.
- **Q:** Why an overlay and not a header inserted into the list? **A:** An inserted header moves the content when it appears and disappears. The overlay draws above the content without any layout change.
- **Q:** Why does settle wait for the program's read? **A:** The same reason as the iOS hook: the report is complete only when the program has handled it. Ending the indicator earlier would hide a pull the program can still answer.

## Referenced by

[[src/cbits/pudu-android-routes]] · [[src/android/org/pudu/PuduActivity]] · [[pudu_ios_refresh.h]] · [[NATIVE-MOBILE]]
