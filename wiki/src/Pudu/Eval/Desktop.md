---
type: module
path: "@root/src/Pudu/Eval/Desktop.hs"
fidelity: Active
tags: [module, runtime, ui, desktop]
aliases: [Eval Desktop]
---

# Eval Desktop

## Purpose and interface

Own desktop window resources for one evaluator lifetime. `newDesktopStore` creates an empty token
registry; `openDesktop`, `presentDesktop`, `pumpDesktop`, `inputsDesktop`, and `closeDesktop` validate each
operation against it; `closeDesktopStore` releases every remaining native window during runtime teardown.

On macOS, a private adapter calls public window-server APIs. On other targets every open answers
the stable `unsupported platform` failure without manufacturing a token. There the store is an
empty constructor: it owns no registry, teardown does nothing, and every import and helper that
only the adapter uses sits inside the platform guard, so a target without the adapter builds with
warnings as errors. Platform handles never become Pudu values. The runtime copies presented bytes before returning and performs all adapter
calls on the main OS thread.

`inputsDesktop` drains the adapter's input queue in two native calls: one measures it and one
copies it. The adapter copies only a queue that fits, so input arriving between the calls waits for
the next drain rather than being truncated. The bytes are decoded as UTF-8 leniently; the records are
parsed in `Std.Ui.Desktop`, not here.

The registry lock remains held while a native present, pump, or close uses a handle. This makes a
concurrent close wait rather than free a pointer beneath another operation. A failed close retains
the token for retry; only confirmed native release removes it.

## Negative logic

- No process-global Haskell registry and no pointer-shaped language value.
- No access after token removal and no leaked session after evaluator exit.
- No present/close or pump/close race over one native pointer.
- No toolkit binding: the target adapter is window-server plumbing beneath the Pudu API.
- No exception or native failure escapes as an untyped evaluator abort.

## Grill Log

- **Q:** Reuse `ForeignStore`? **A:** No. _Rationale:_ desktop presentation is a language-owned
  capability with stable semantics, not a program-declared ABI assertion. _Rejected:_ asking every
  application to declare AppKit calls.
- **Q:** Let any evaluator worker present? **A:** No. _Rationale:_ macOS window operations are
  main-thread isolated. _Rejected:_ dispatching synchronously to the main queue from an evaluator
  already blocking that queue.
- **Q:** Keep native handles after close for idempotence? **A:** No. _Rationale:_ stale tokens must
  fail deterministically and cannot alias a later resource. _Rejected:_ pointer reuse as identity.
- **Q:** Pump events through an unsafe foreign call? **A:** No. _Rationale:_ a pump waits up to a
  caller-chosen duration, and an unsafe call holds every other capability out of garbage collection
  for that whole wait. _Accepted:_ a safe call, which keeps the bound main thread's OS thread; open,
  present, and close stay unsafe because they return without waiting.
- **Q:** Make one native pump for the whole requested duration? **A:** No. _Rationale:_ a thread
  inside a foreign call receives no interrupt until it returns, so Ctrl-C during a 10-second pump
  waited the full 10 seconds, and `guarded` then reported it as `PlatformFailure("user interrupt")`
  while the program continued and exited 0. _Accepted:_ native pumps of at most 16 ms against a
  monotonic deadline, with the program's stop flag checked between them, and `guarded` re-raising
  every asynchronous exception. _Rejected:_ pumping on a worker thread, because window-server calls
  must stay on the main thread.

## Referenced by

[[Eval Runtime]] · [[Eval Effect]] · [[Native Application UI]]
