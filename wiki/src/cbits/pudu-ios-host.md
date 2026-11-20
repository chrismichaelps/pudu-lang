---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_host.m"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Adapter]
---

# iOS Host Adapter

## Purpose and interface

The view stream reader lives in [[iOS Host Stream]]; this file keeps dispatch, node lookup and placement. The host is about 485 lines.

The Objective-C host of a Pudu Native application on iOS. It starts the program, applies the streams the program produces to UIKit controls, and returns control events to the program. It carries no application logic. The compiler embeds this file at build time beside the desktop host sources ([[Native Toolchain Host Sources]]) and writes it out when it builds an application; it is never compiled into the compiler.

Entry points the program depends on:
- `pudu_ui_apply(const void *stream, uint64_t length)`: applies one commit.
- `pudu_ui_wait()`: returns one 64-bit event.

## Behavior

- Starts `pudu_program_run` from a run-loop timer once UIKit has launched.
- `pudu_ui_apply` applies every instruction of one stream in order. Instruction codes dispatch through `pudu_instruction_table`, one handler per code. The instruction codes, the control kinds and the node table come from [[pudu_ios_nodes.h]]: `pudu_nodes` is indexed by node, and `pudu_kinds` holds each node's kind.
- Control kinds dispatch through the constant table `pudu_kind_table`, indexed by kind; the table is defined in [[pudu-ios-kinds]]. Each entry names the factory that makes the control, the setters it accepts (text, hint, state), the control that carries tag and accessible name (a toggle's switch, otherwise the view), the stack accessor for its children when present, the paint and style hooks used by [[iOS Host Theme]], and what a self-test does to it (`fill`, `press`) and reports (`shown`).
- The headers [[iOS Host Events]], [[iOS Host Controls]], [[iOS Host Theme]], [[iOS Host List]] and [[iOS Host Material]] are included by this file, as are the capability headers [[iOS Host Gesture]], [[iOS Host Feedback]], [[iOS Host Access]], [[iOS Host Scene]], [[iOS Host Motion]] and [[iOS Host Capability Test]]. The controls header holds the platform controls and their factories; this file keeps the stream reader, the kind table, the instruction table and the application delegate, and is about 400 lines. The theme header adds the THEME, APPEARANCE, STYLE and COLOR handlers; the list header adds RANGE and COLUMNS; the material header adds MATERIAL. The instruction table dispatches the capability codes 27 to 35 to nine handlers, one for each capability instruction. The event queue lives in [[iOS Host Events]]; this file keeps the host's kinds, nodes and placement.
- INSERT and MOVE share one placement handler in the instruction table.
- Kind table fields added for theming: `paint` and `style` name the hooks that apply a role or a text style, and `inked` says whether the kind takes Ink without an explicit COLOR. Labels, fields and toggles are inked; buttons follow the tint; groups have no `paint` or `style`.
- The keyboard self-test is `pudu_test_keyboard` in [[iOS Host Layout]]. This file calls it with explicit parameters: the root surface, the shown root, the node table and a `done` block.
- First-frame timing uses `CACurrentMediaTime`, not a private clock helper.
- An instruction a kind does not accept, an unknown code or kind, a truncated stream, or a node that was never created stops the process with a message naming the defect.
- INSERT and MOVE place a child at an index of a group. An arranged child already present moves. An index past the group's end, or a node that holds nothing, is refused.
- REMOVE detaches a subtree root and forgets every id it lists, so CREATE may reuse them. A removed node is also dropped from its row store when it belongs to a list.
- Kind 7 makes a vertical scroll viewport with its content stack pinned to the content guide and sized to the frame guide across its width.
- Kind 8 makes a list. A LIST node's children are held by a row store, and its cells, layout and scroll reports are implemented by [[iOS Host List]]. A list root fills the safe-area region like a scroll viewport. The kind table names the list's store accessor and its reload hook.
- [[iOS Host Layout]] implements geometry and focus. Root layout uses the safe area and the docked keyboard guide. A scroll root fills the available bounds. Ordinary roots stay centered with edge constraints. A focused field in the viewport is revealed at focus and when the viewport resizes.
- Field text is left alone when it already matches, so typing keeps the cursor.
- `pudu_ui_wait`, `pudu_ui_event_text` and `pudu_ui_event_detail` are implemented by [[iOS Host Events]]. Each queued event carries its text and its detail word.
- Self-test: `PUDU_UI_TYPE=text` types into every field and switches every toggle on; `PUDU_UI_SELFTEST=n` then presses every button n times, and a stop event is queued. After the program returns, it prints `PUDU_PROGRAM_STATUS` with the status, prints every label's text as `PUDU_LABEL ...` in screen order by walking the shown tree through group kinds, and exits with the program's status.
- Always prints `PUDU_FIRST_FRAME_MS`: monotonic milliseconds from `main` to the first applied and laid-out stream.
- Self-test `PUDU_UI_THEME_TEST` prints the theme checks described in [[iOS Host Theme]] and then asks the program to stop.
- Self-test `PUDU_UI_LIST_TEST` runs the list check described in [[iOS Host List]] and then asks the program to stop.
- Kind 9 makes a material node: a visual-effect view whose content view holds a vertical stack, realized as glass or as a system blur by [[iOS Host Material]]. The kind table names its stack accessor, so placement and traversal share the group path.
- Self-test `PUDU_UI_MATERIAL_TEST` runs the material check described in [[iOS Host Material]], prints `PUDU_MATERIAL glass` or `PUDU_MATERIAL blur` for the first material node, and then asks the program to stop.
- Kind 10 makes a determinate progress bar and kind 11 an activity indicator; both are leaves. VALUE sets the bar's completion and STATE starts or stops the indicator ([[iOS Host Feedback]]).
- The application's root controller is `PuduRootController`. It reports the scene's size and size classes as RESIZED from its layout pass, and only when they change ([[iOS Host Scene]]).
- Lifecycle observation: the host queues LIFECYCLE for the four application notifications, in the order the platform posts them ([[iOS Host Scene]]).
- Capability instructions GESTURES, ALERT, VALUE, HAPTIC, TRAITS, ACCESS_HINT, ACCESS_VALUE, MENU and ANIMATE dispatch to [[iOS Host Gesture]], [[iOS Host Feedback]], [[iOS Host Access]] and [[iOS Host Motion]]. An out-of-range mask, style, role, haptic code or trait mask is a stream defect.
- REFRESH (37) dispatches to `pudu_do_refresh`, which lives in [[pudu_ios_refresh.h]]. It is refused on a node that is neither a scroll nor a list, with the message `pudu: refreshed a node that does not scroll:` followed by the node id.
- Motion: after every commit, the host runs one animation for the surface if an animated group changed in that commit. With Reduce Motion on, the change is applied at once ([[iOS Host Motion]]).
- Self-test `PUDU_UI_REFRESH_TEST` runs the pull check of [[pudu_ios_refresh.h]], prints its `PUDU_REFRESH` lines and then asks the program to stop.
- FETCH (38), CANCEL (39) and WAKE (40) dispatch to `pudu_do_fetch`, `pudu_do_cancel` and `pudu_do_wake` in [[pudu_ios_fetch.h]], which sends the program's requests on the platform URL session and answers them as FETCHED events.
- A memory warning observer, `pudu_observe_memory`, is registered at launch. Each warning queues MEMORY ([[pudu_ios_fetch.h]]).
- Self-test `PUDU_UI_FETCH_TEST` runs the wait for both Remote lines of [[Native Remote Example]] and prints `PUDU_FETCH loaded` once they show a loaded result, then asks the program to stop.
- Self-test `PUDU_UI_CAPABILITY_TEST` runs the sequence of [[iOS Host Capability Test]], queues a stop event after it, and after the program returns prints `PUDU_ACCESS` and `PUDU_MOTION` lines.
- NAVIGATE (36) is read whole by `pudu_navigation_read` in [[pudu_ios_navigation.h]] before any controller changes; each route body is read through `pudu_node_id` and `pudu_node_scrolls` in [[pudu_ios_nodes.h]]. Only then is the shown root removed and the navigation shown over the root controller, which installs the platform stack on first use. Its user pop and sheet dismissal events are queued through [[iOS Host Events]].
- Self-test `PUDU_UI_NAVIGATION_TEST` runs the stack and sheet check described in [[pudu_ios_navigation.h]] and then asks the program to stop. It prints `PUDU_NAV` lines.
- When navigation is installed, the report walks the top page's body rather than the root's shown tree, so `PUDU_LABEL` lines name the labels the user sees.
- Links (#978): the URL in the launch options, when the application was opened by a link, and each `application:openURL:options:` call queue LINKED (30) with the URL text. Self-test `PUDU_UI_LINK_TEST` opens the URL it names through [[pudu-ios-system]], prints `PUDU_SYSTEM link opened` or `refused`, and then asks the program to stop.

## Negative Logic

- No application logic. A control means only its tag, its text and its state.
- Without `PUDU_UI_SELFTEST`, no taps are generated; only user touches queue events.
- No dispatch to the main queue to start the program.
- No retry of a malformed stream. The defect ends the process.
- No setter a kind's table entry does not name. A mismatched instruction is refused, never ignored.
- No animation of an unmarked group. Motion runs only for groups the program marked with ANIMATE.

## Dependencies and consumers

Implements the four symbols of [[Std Mobile Host]]. Its streams come from [[Std Mobile View]] and [[Std Mobile Theme]]. Includes [[iOS Host Events]], [[iOS Host Controls]], [[iOS Host Theme]], [[iOS Host List]], [[iOS Host Material]], [[iOS Host Gesture]], [[iOS Host Feedback]], [[iOS Host Access]], [[iOS Host Scene]], [[iOS Host Motion]], [[iOS Host Capability Test]], [[pudu_ios_nodes.h]], [[pudu_ios_navigation.h]], [[pudu_ios_refresh.h]] and [[pudu_ios_fetch.h]]. Used by the counter [[Native Counter Example]] and by the simulator run [[iOS Simulator Run]]. [[Pudu Native]] limits hand-written native code to this platform shim.

## Resolved Grill Log

- **Q:** How does a scroll viewport participate in the existing host protocol? **A:** The kind can return its inner stack, so placement and traversal share the group path. Root geometry uses the keyboard guide to shrink available space while the docked keyboard is visible.

- **Q:** Why a run-loop timer rather than the main dispatch queue to start the program? **A:** Pudu's wait runs the main loop from inside the start call. The main queue does not drain while one of its own blocks is running, so timers and controls still fire. _Rejected:_ `dispatch_async` to the main queue.
- **Q:** Why tables instead of branching on kind? **A:** Adding a control is one table entry with its factory and setters, and a mismatch is refused by the missing setter. _Rejected:_ if-ladders over kinds and classes.
- **Q:** Why is the host hand-written? **A:** [[Pudu Native]] limits hand-written native code to the platform shim. It carries no application logic, so the same program runs on any host that implements the two symbols.

- **Q:** Why one animation per commit? **A:** Placements that arrive together move together, and Reduce Motion is checked once. See [[iOS Host Motion]].

## Referenced by

[[Native Mobile Targets]] · [[Std Mobile Host]] · [[iOS Simulator Run]] · [[Backend Toolchain App]] · [[Native First Light Delivery]] · [[Native Controls Delivery]] · [[Native iOS Scrolling Delivery]] · [[Native iOS Theming Delivery]] · [[Native iOS Recycling Delivery]] · [[Native iOS Materials Delivery]] · [[Native iOS Capabilities Delivery]] · [[Native iOS Refresh Delivery]]
