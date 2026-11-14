---
type: module
path: "@root/host/ios/PuduHost.m"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Adapter]
---

# iOS Host Adapter

## Purpose and interface

The Objective-C host of a Pudu Native application on iOS. It starts the program, applies the streams the program produces to UIKit controls, and returns control events to the program. It carries no application logic.

Entry points the program depends on:
- `pudu_ui_apply(const void *stream, uint64_t length)`: applies one commit.
- `pudu_ui_wait()`: returns one 64-bit event.

## Behavior

- Starts `pudu_program_run` from a run-loop timer once UIKit has launched.
- `pudu_ui_apply` applies every instruction of one stream in order. It keeps controls in a table indexed by node: a UIStackView for each column, a UILabel for each label, and a system UIButton for each button.
- A malformed stream stops the process with a message naming the defect: a truncated instruction or text, a node that was never created, or an unknown code or kind.
- `pudu_ui_wait` runs the main run loop in the default mode until a control has queued an event. A button tap queues `1 << 32 | tag`.
- With `PUDU_UI_SELFTEST=n`, the host taps every button n times after launch and queues a stop event. After the program returns, it prints `PUDU_PROGRAM_STATUS` with the status, prints every label's text as `PUDU_LABEL ...`, and exits with the program's status.
- Always prints `PUDU_FIRST_FRAME_MS`: monotonic milliseconds from `main` to the first applied and laid-out stream.

## Negative Logic

- No application logic. A control means only its tag.
- Without `PUDU_UI_SELFTEST`, no taps are generated; only user touches queue events.
- No dispatch to the main queue to start the program.
- No retry of a malformed stream. The defect ends the process.

## Dependencies and consumers

Implements the two symbols of [[Std Mobile Host]]. Its streams come from [[Std Mobile View]]. Used by the counter [[Native Counter Example]] and by the simulator run [[iOS Simulator Run]]. [[Pudu Native]] limits hand-written native code to this platform shim.

## Resolved Grill Log

- **Q:** Why a run-loop timer rather than the main dispatch queue to start the program? **A:** Pudu's wait runs the main loop from inside the start call. The main queue does not drain while one of its own blocks is running, so timers and controls still fire. _Rejected:_ `dispatch_async` to the main queue.
- **Q:** Why is the host hand-written? **A:** [[Pudu Native]] limits hand-written native code to the platform shim. It carries no application logic, so the same program runs on any host that implements the two symbols.

## Referenced by

[[Native Mobile Targets]] · [[Std Mobile Host]] · [[iOS Simulator Run]] · [[Native First Light Delivery]]
