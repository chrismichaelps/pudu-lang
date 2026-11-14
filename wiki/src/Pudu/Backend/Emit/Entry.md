---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/Entry.hs"
fidelity: Active
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, native]
aliases: [Backend Emit Entry]
---

# Backend Emit Entry

## Purpose and interface

How a generated translation unit is entered, and what an emitted unit
reports to the toolchain.

```haskell
data EntryForm = ExecutableEntry | EmbeddedEntry
data EmittedUnit = EmittedUnit
  { emittedSource :: !Text, emittedParts :: !(Set Text), emittedLibraries :: ![(Text, Maybe Text)] }

entrySection :: EntryForm -> Bool -> Bool -> [Text] -> [Text]
embeddedHeader :: [Text] -> Text
embeddedHeaderName :: FilePath
```

## Algorithm and invariants

- `entrySection form arguments buffered body` wraps the entry's body lines
  (hook installation and result reporting, each path ending in `return`).
- `ExecutableEntry` is the desktop form: `int main(void)`, or
  `int main(int count, char **values)` storing the vector when the program
  reads its arguments; then `pudu_prepare_io()`.
- `EmbeddedEntry` emits the same body as `static int pudu_program_main(int
  count, char **values)` (the parameters are voided when unread), then the
  exported `int pudu_program_run(int count, char **values)`, prototyped first,
  which calls it, flushes the buffered outputs (`pudu_output_finish`, only when
  the buffered output part is selected) and `stdout`/`stderr`, and returns the
  status.
- `embeddedHeader links` is the guarded C header declaring
  `pudu_program_run` inside `extern "C"` for C++ hosts, with a comment naming
  each system library the host must link. `embeddedHeaderName` is
  `pudu_program.h`.

## Negative Logic (Prohibited Paths)

- The embedded entry never runs the program body twice in one process.
- No `main` in an embedded unit; no exported symbol besides the entry.
- No teardown export: the run releases what it owns before returning.

## Dependencies and consumers

`containers`, `text`. Consumed by [[Backend Frame Program]],
[[Backend Emit]] and [[Backend Toolchain Library]].

## Resolved Grill Log

- **Q:** Why a static inner function instead of renaming `main`? **A:** Every
  reporting path ends in `return`; calling it lets the outer function flush once
  for all of them. _Rejected:_ inserting a flush before each `return`.
- **Q:** Why flush `stdout` too? **A:** The scalar printers write through
  stdio; a host that keeps running would otherwise hold them until exit.
- **Q:** May a host start the program twice? **A:** No (#899). The runtime
  registers process hooks and frame state once and is never reset, so a second
  run would reuse released state. A C11 atomic flag admits the first call from
  any thread; every later call, concurrent or repeated, returns
  `PUDU_PROGRAM_ALREADY_STARTED` (`-1`) before touching runtime state.
  _Rejected:_ a mutex (it would block a host thread instead of answering) and
  a reset path (no teardown evidence for the runtime's process state).

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Mobile Targets]] · [[Backend Frame Program]] ·
[[Native Calls Delivery]]
