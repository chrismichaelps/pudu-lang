---
type: module
path: "@root/lib/Std/Dotenv.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, configuration, environment]
aliases: [Std Dotenv]
---

# Std Dotenv

## Purpose and interface

Environment files: `KEY=value` lines read into ordered entries, and entries written back.

Exports:
- `type DotenvError = MissingEquals(Int) | InvalidKey(Int, Str) | Unterminated(Int) | Unreadable(Str, Str)`.
- `type Entry = { key: Str, value: Str }`.
- `parse(text: Str) -> Result[Array[Entry], DotenvError]`.
- `load(path: Str) -> Result[Array[Entry], DotenvError]`.
- `toMap(entries) -> Map[Str, Str]`, `lookup(entries, key) -> Option[Str]` (last assignment wins).
- `render(entries) -> Str`: text that `parse` reads back to the same entries.
- `explain(problem) -> Str`.

## Semantics

- Blank lines and `#` lines are skipped; a leading `export ` is ignored.
- Unquoted values are trimmed and end at ` #`. Single quotes are literal. Double quotes may span
  lines and read `\n`, `\r`, `\t`, `\"`, `\\`, `\$`.
- `${NAME}` expands in unquoted and double-quoted values from keys assigned earlier in the same text;
  an unknown name expands to nothing. The process environment is never read.
- Keys are ASCII letters, digits, `_`, and `.`, not starting with a digit.

## Grill Log

- **Q:** Write the entries into the process environment? **A:** No. _Rationale:_ the language has no
  ambient global mutation; the entries are a value a program passes to [[Std App Config]] or reads
  directly. _Rejected:_ a `loadIntoEnvironment` effect.
- **Q:** Expand from the process environment? **A:** No. _Rationale:_ the same file would then parse
  differently on each machine, and a test could not state its answer. _Rejected:_ implicit fallback.
- **Q:** Ordered entries or a map? **A:** Entries; `toMap` is one call away and order is needed to
  render a file back and to report duplicates.

## Dependencies and consumers

- Depends on `Std.Char` and the prelude `readFile` effect.
- Consumed by service start-up and [[Std App Config]] callers.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
