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

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Mobile Targets]] · [[Backend Frame Program]]
