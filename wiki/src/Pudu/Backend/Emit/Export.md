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

exportSection :: Layouts -> Set Text -> [(Int, FrameFunction)] -> [Text] -> Either FrameFault ExportSection
```

The first argument is the module's record and sum layouts; the second is the
set of direct functions from [[Backend Frame Direct]]; the third is the indexed
frame functions; the fourth is the module's export keys from [[Core Frame IR]].

## Algorithm and invariants

- `exportCode` begins with the crossing declarations, so the program and the header declare the same structs. `exportPrototypes` is the declarations, then the crossing prototypes, then one prototype per export. The misuse name passed to conversions is the export's name.
- Each export `name` becomes `pudu_export_<name>`. Parameters and plain results
  use the shapes of [[Backend Export Crossing]]: scalars, `pudu_string` text and
  `pudu_<Name>` records.
- An export returning `Result[T, E]` returns `int`: 0 for `Ok`, 1 for `Err`. It
  takes a `T *` and an `E *` after its parameters (omitted when that payload is
  `()`); a null pointer means the host does not want that payload. The outcome
  box is released before returning.
- Owned argument cells (text, records) are released by the wrapper after the
  call: the callee's frame took its own reference. Owned result cells are
  released after conversion, so each value is released exactly once.
- An argument converts with `fromAbi` straight into a stack array of cells; the
  result converts with `toAbi`. Nothing is looked up, boxed, or allocated per
  call beyond the frame every call already takes.
- A direct export calls `pudu_direct_<n>` with its converted arguments, so a host call
  costs the admission checks and one C call. Any other export pushes its frame with
  `pudu_new_frame` and runs it with `pudu_run_active`, under the same cleanup and blame
  hooks.
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

- No export whose parameter or result has no crossing: sums other than a
  `Result` result, closures, collections, bytes and handles are refused with a
  located fault at the export.
- No dispatch table and no lookup by name at run time.
- No entry into the runtime from a second thread or from within a running call.

## Dependencies and consumers

Uses [[Backend Emit Foreign ABI]], the conversion needs of
[[Backend Emit Foreign]] and [[Backend Export Crossing]]. Consumed by [[Backend Frame Program]] for the
embedded form only; the prototypes reach [[Backend Toolchain Library]] through
[[Backend Emit Entry]].

## Defaulted and async crossings

A host provides every written parameter. The wrapper fills the hidden count
when the body accepts omitted Pudu arguments. A monomorphic async export
enters the await body from [[Compiler Lower]] on the owning thread and
returns the completed value or Result through the regular crossing.

## Grill Log

- **Q:** Why abort on a wrong-thread or early call instead of returning a
  status? **A:** An export returns the function's own value, so there is no
  status channel; the misuse is the host's, and continuing would read runtime
  state another thread owns. _Rejected:_ undefined behavior, and a hidden lock
  that would serialize host threads.
- **Q:** Why reuse the frame engine instead of emitting a plain C body? **A:**
  The frame layout and its ownership, depth and failure rules are the reference;
  a direct export keeps that layout on the C stack ([[Backend Frame Direct]]) and
  only removes the allocation and dispatch.
- **Q:** Why require the start first? **A:** `pudu_program_run` prepares the
  process state once; an export before it would either run without that state
  or prepare it a second time. _Rejected:_ lazy preparation inside every
  export.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Frame Program]] · [[Native Calls Delivery]]
