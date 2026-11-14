---
type: module
path: "@root/lib/Std/Mobile/Host.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, foreign]
aliases: [Std Mobile Host]
---

# Std Mobile Host

## Purpose and interface

Platform module of the mobile stack. It holds the foreign declarations of the host ABI, so [[Std Mobile View]] stays pure, as [[Native Application UI]] requires for portable UI.

Exports:
- `apply(stream: Bytes) -> ()`: hands one commit to `pudu_ui_apply(const void *stream, uint64_t length)` in a single foreign call.
- `wait() -> View.Event`: calls `pudu_ui_wait()` and decodes its 64-bit result with `View.event`.

## Invariants

- Each commit crosses the boundary once. One `apply` carries the whole stream, never one call per instruction.
- Every call runs on the thread that runs the program. The host adapter [[iOS Host Adapter]] keeps its controls on that thread.
- `wait` returns one event per call. Events queued while no call is waiting are delivered by later waits in the order the controls queued them.
- These two declarations are the only foreign declarations in the mobile library.

## Negative Logic

- No platform callback enters Pudu. No exported function receives events.
- No validation of the stream here. A malformed stream is refused by the host adapter, which ends the process with a message naming the defect.
- No node table and no control handles; those live in the host.
- No timeout on `wait`. The loop ends on a `Stopped` event.

## Dependencies and consumers

Depends on [[Std Mobile View]] for `Event` and `event`. Consumers: [[Native Counter Example]]. The host side is [[iOS Host Adapter]], which defines `pudu_ui_apply` and `pudu_ui_wait`.

## Resolved Grill Log

- **Q:** Why does Pudu wait for events instead of the platform calling into Pudu? **A:** The model is a local of the entry's loop, and the language has no global mutable state. A blocking wait keeps every Pudu call on the one thread that owns the runtime and needs no reentry. _Rejected:_ platform callbacks into exported functions for events.
- **Q:** Why one crossing per commit? **A:** A stream is one ordered batch, so the cost of the boundary does not grow with the size of the tree. _Rejected:_ one foreign call per control or per property.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[iOS Host Adapter]] · [[Native First Light Delivery]]
