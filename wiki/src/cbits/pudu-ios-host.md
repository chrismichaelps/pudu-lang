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

The Objective-C host of a Pudu Native application on iOS. It starts the program, applies the streams the program produces to UIKit controls, and returns control events to the program. It carries no application logic. The compiler embeds this file at build time beside the desktop host sources ([[Native Toolchain Host Sources]]) and writes it out when it builds an application; it is never compiled into the compiler.

Entry points the program depends on:
- `pudu_ui_apply(const void *stream, uint64_t length)`: applies one commit.
- `pudu_ui_wait()`: returns one 64-bit event.

## Behavior

- Starts `pudu_program_run` from a run-loop timer once UIKit has launched.
- `pudu_ui_apply` applies every instruction of one stream in order. Instruction codes dispatch through `pudu_instruction_table`, one handler per code. Nodes live in a table indexed by node.
- Control kinds dispatch through the constant table `pudu_kind_table`, indexed by kind. Each entry names the factory that makes the control, the setters it accepts (text, hint, state), the control that carries tag and accessible name (a toggle's switch, otherwise the view), whether it holds children, and what a self-test does to it (`fill`, `press`) and reports (`shown`).
- An instruction a kind does not accept, an unknown code or kind, a truncated stream, or a node that was never created stops the process with a message naming the defect.
- INSERT and MOVE place a child at an index of a group. An arranged child already present moves. An index past the group's end, or a node that holds nothing, is refused.
- REMOVE detaches a subtree root and forgets every id it lists, so CREATE may reuse them.
- Field text is left alone when it already matches, so typing keeps the cursor.
- `pudu_ui_wait` runs the main run loop in the default mode until a control has queued an event. Events are queued with the text they carry. `pudu_ui_event_text` answers the text of the last event until the next wait.
- Self-test: `PUDU_UI_TYPE=text` types into every field and switches every toggle on; `PUDU_UI_SELFTEST=n` then presses every button n times, and a stop event is queued. After the program returns, it prints `PUDU_PROGRAM_STATUS` with the status, prints every label's text as `PUDU_LABEL ...` in screen order by walking the shown tree through group kinds, and exits with the program's status.
- Always prints `PUDU_FIRST_FRAME_MS`: monotonic milliseconds from `main` to the first applied and laid-out stream.

## Negative Logic

- No application logic. A control means only its tag, its text and its state.
- Without `PUDU_UI_SELFTEST`, no taps are generated; only user touches queue events.
- No dispatch to the main queue to start the program.
- No retry of a malformed stream. The defect ends the process.
- No setter a kind's table entry does not name. A mismatched instruction is refused, never ignored.

## Dependencies and consumers

Implements the three symbols of [[Std Mobile Host]]. Its streams come from [[Std Mobile View]]. Used by the counter [[Native Counter Example]] and by the simulator run [[iOS Simulator Run]]. [[Pudu Native]] limits hand-written native code to this platform shim.

## Resolved Grill Log

- **Q:** Why a run-loop timer rather than the main dispatch queue to start the program? **A:** Pudu's wait runs the main loop from inside the start call. The main queue does not drain while one of its own blocks is running, so timers and controls still fire. _Rejected:_ `dispatch_async` to the main queue.
- **Q:** Why tables instead of branching on kind? **A:** Adding a control is one table entry with its factory and setters, and a mismatch is refused by the missing setter. _Rejected:_ if-ladders over kinds and classes.
- **Q:** Why is the host hand-written? **A:** [[Pudu Native]] limits hand-written native code to the platform shim. It carries no application logic, so the same program runs on any host that implements the two symbols.

## Referenced by

[[Native Mobile Targets]] · [[Std Mobile Host]] · [[iOS Simulator Run]] · [[Backend Toolchain App]] · [[Native First Light Delivery]] · [[Native Controls Delivery]]
