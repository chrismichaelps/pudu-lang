---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_android_routes.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, android, native, navigation, refresh, fetch, wake, jni]
aliases: [Android Host Routes, pudu_android_routes.h]
---

# pudu_android_routes.h

## Purpose and interface

Private route implementation of the Android host, included once by the Android host translation unit `pudu_android_host.c`. It realizes five instructions of [[Std Mobile Stream]]: NAVIGATE (36), REFRESH (37), FETCH (38), CANCEL (39) and WAKE (40). The numbering is the one shared with the iOS host ([[NATIVE-MOBILE]]). The Java side does the platform work on the main thread: [[PuduNavigator]] for the page stack and page sheet, [[PuduRefresh]] for pull to refresh, [[PuduFetch]] for requests and the wake timer.

The header provides:
- `pudu_do_navigate`: reads a presentation, checks it whole, then sends it to `PuduBridge.navigate`.
- `pudu_refresh_settle`: the hook that passes the tags of still-queued REFRESHED events to `PuduBridge.settleRefresh`. It is installed as `pudu_before_wait` by the first REFRESH.
- `pudu_do_refresh`: reads a node, a reported tag and a flag, checks them, installs the settle hook and sends `PuduBridge.refresh`.
- `pudu_do_fetch`: reads a request whole, checks the generation and the answer of `PuduBridge.fetch`.
- `pudu_do_cancel`: sends `PuduBridge.cancelFetch` and drops an unread FETCHED for that generation.
- `pudu_do_wake`: sends `PuduBridge.wake` with a delay in milliseconds.
- `pudu_node_scrolls`: true for scroll and list kinds. Its kinds come from [[pudu_android_kinds.h]].

The enumeration `PUDU_FETCH_SENT`, `PUDU_FETCH_REPEATED` and `PUDU_FETCH_UNREADABLE` (0, 1, 2) is the answer the Java side returns for a request.

## Behavior

- NAVIGATE reads the route count, then per route an id, a body node and a title. A count of 0 is refused with `showed a navigation without a root route, count` followed by the count. Two routes with one id are refused with `showed two routes with id` followed by the id. Then the sheet flag is read: a value above 1 is refused with `marked a sheet with` followed by the value. A flag of 1 is followed by the sheet's id and body node; a sheet id equal to a route id is refused with `showed a sheet sharing a route's id` followed by the id. Every check runs before the screen changes.
- A checked NAVIGATE drops any unread POPPED and DISMISSED events, since they refer to a stack the program has replaced. It clears the root record of the shown page and passes the route arrays, the sheet and whether each body fills its area to `PuduBridge.navigate`. A body fills when its node is a scroll or list kind.
- REFRESH reads the node, the tag its pulls report and the flag. A node that does not scroll is refused with `refreshed a node that does not scroll:` followed by the node id. A flag above 1 is refused with `set refreshing to` followed by the value. The settle hook is installed before the call, so the first REFRESH arms it.
- The settle hook runs on the program thread before each wait. It collects the tags of queued REFRESHED events with `pudu_queued_tags`, up to `PUDU_EVENT_SCAN` entries, and passes them as an int array. Java ends each unanswered pull whose tag is absent from that array.
- FETCH reads the generation, the method, the URL, the header count, the header pairs and the body, in that order. Generation 0 is refused with `sent a request without a generation` followed by the value. The Java side answers `PUDU_FETCH_UNREADABLE` for a URL it cannot parse, refused with `sent a request to an unreadable URL, generation` followed by the generation. `PUDU_FETCH_REPEATED` for a generation already in flight is refused with `sent two requests under generation` followed by the generation. A JNI failure is checked by `pudu_checked` before either answer is read.
- CANCEL passes the generation to Java and then drops any unread FETCHED with that tag. A generation that is unknown or already answered is ignored by Java, so a late cancel is harmless.
- WAKE passes the delay. Java replaces any earlier wake, so the last WAKE wins and one WOKE is posted.

## Invariants

- Every check that can refuse an instruction runs before any call that changes the screen, the request table or the wake timer.
- The tag arrays passed to the settle hook are read from the queue on the program thread, so the Java side sees the queue as it was before the program's next wait.
- Only the program thread touches the queue and the settle hook; Java posts to the main thread for every platform change.

## Negative Logic

- No refusal by the Java side for a defect of the program. Java reports `PUDU_FETCH_UNREADABLE` and `PUDU_FETCH_REPEATED` as answers, and this header turns them into stream defects.
- No drop of POPPED or DISMISSED for a CANCEL or WAKE. Only NAVIGATE replaces the stack those reports refer to.
- No REFRESHED event for a refresh the program starts. The settle hook never queues an event.
- No cancellation of an unknown generation. CANCEL of an answered generation is not an error.

## Dependencies and consumers

Depends on [[pudu_android_events.h]] for the queue, its unread drop and tag scan, on [[pudu_android_jni.h]] for `pudu_bridge`, `pudu_static` and `pudu_checked`, on [[pudu_android_nodes.h]] for node ids and node views, and on [[pudu_android_kinds.h]] for node kinds. Consumers are the Android host translation unit [[pudu_android_host.c]], which includes this header, and the Java classes [[PuduNavigator]], [[PuduRefresh]], [[PuduFetch]] and [[PuduBridge]]. The iOS counterparts are [[pudu_ios_navigation.h]], [[pudu_ios_refresh.h]] and [[pudu_ios_fetch.h]]; the messages and checks follow them.

## Resolved Grill Log

- **Q:** Why do the checks live in C rather than in the Java side? **A:** A defect must be refused before anything changes. Java receives only arrays it can apply; a refused instruction never reaches the platform, so the screen and the request table keep their previous state. Java only does platform work.
- **Q:** Why does the settle hook run on the program thread? **A:** The program has handled its last event exactly when it waits again. Reading the queue at that point gives a complete answer to "has the program read this pull". Running it at any other time would end a pull the program has not yet seen.
- **Q:** Why does a newer NAVIGATE drop unread POPPED and DISMISSED? **A:** Both report a page of the stack being replaced. Delivering them after the new stack would make the program pop a route that is no longer there.

## Referenced by

[[src/cbits/_MOC]] · [[NATIVE-MOBILE]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[pudu_ios_navigation.h]] · [[pudu_ios_refresh.h]] · [[pudu_ios_fetch.h]] · [[PuduNavigator]] · [[PuduRefresh]] · [[PuduFetch]]
