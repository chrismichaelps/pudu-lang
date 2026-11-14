---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/Export.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, backend, emit, native, mobile]
aliases: [Backend Emit Export]
---

# Backend Emit Export

## Purpose and interface

Emit, for an embedded library, one C function per exported Pudu function so a
host application calls Pudu directly, and the prototypes its header declares.

```haskell
data ExportSection = ExportSection
  { exportCode :: ![Text]
  , exportPrototypes :: ![Text]
  , exportNeeds :: ![Text]
  }

exportSection :: [(Int, FrameFunction)] -> [Text] -> Either FrameFault ExportSection
```

The first argument is the indexed frame functions; the second is the module's
export keys from [[Core Frame IR]].

## Algorithm and invariants

- Each export `name` becomes `pudu_export_<name>`, with the C types
  [[Backend Emit Foreign ABI]] assigns: fixed-width integers, `float`,
  `double`, `uint8_t` for `Bool`, and `void` for a `()` result.
- An argument converts with `fromAbi` straight into a stack array of cells; the
  result converts with `toAbi`. Nothing is looked up, boxed, or allocated per
  call beyond the frame every call already takes.
- The call pushes the function's frame with `pudu_new_frame` and runs it with
  `pudu_run_active`, exactly as a call inside the program does, under the same
  cleanup and blame hooks.
- `pudu_export_enter` admits the call only after `pudu_program_run` has
  returned, only on the thread that ran it, and never while Pudu is already
  running a call. A violation writes one line naming the export to standard
  error and aborts: it is a host programming error, not a program failure.
- Both standard streams are flushed when the call enters and before it
  returns. Pudu writes its descriptors directly, so host output still in a
  stdio buffer would otherwise appear after Pudu's; flushing an empty buffer
  makes no system call, so a call that prints nothing pays nothing.
- The runtime parts the conversions need are reported in `exportNeeds`, so a
  program without exports selects nothing new.

## Negative Logic (Prohibited Paths)

- No export whose parameter or result type has no C shape here: text, bytes,
  handles, records, sums, closures and collections are refused with a
  located fault at the export.
- No dispatch table and no lookup by name at run time.
- No entry into the runtime from a second thread or from within a running call.

## Dependencies and consumers

Uses [[Backend Emit Foreign ABI]] and the conversion needs of
[[Backend Emit Foreign]]. Consumed by [[Backend Frame Program]] for the
embedded form only; the prototypes reach [[Backend Toolchain Library]] through
[[Backend Emit Entry]].

## Grill Log

- **Q:** Why abort on a wrong-thread or early call instead of returning a
  status? **A:** An export returns the function's own value, so there is no
  status channel; the misuse is the host's, and continuing would read runtime
  state another thread owns. _Rejected:_ undefined behavior, and a hidden lock
  that would serialize host threads.
- **Q:** Why reuse the frame engine instead of emitting a plain C body? **A:**
  The frame path is the native reference for every call: ownership, depth
  accounting and failure reporting already hold there. A frameless leaf path
  is a later optimization gated on a measured `-O2` comparison on device.
- **Q:** Why require the start first? **A:** `pudu_program_run` prepares the
  process state once; an export before it would either run without that state
  or prepare it a second time. _Rejected:_ lazy preparation inside every
  export.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Frame Program]] · [[Native Calls Delivery]]
