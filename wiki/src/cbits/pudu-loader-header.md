---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_loader.h"
fidelity: Active
grammar: C11
aliases: [Foreign Platform Loader]
---

# Foreign Platform Loader

Provide open, symbol lookup, close and immediate error capture for the
interpreter bridge, generated C11 and the bundled SQLite adapter. Paths and
error text cross the internal API in UTF-8.

## Interface

- `pudu_loader_open` takes an explicit path, a loader name or a null process name.
- `pudu_loader_symbol` looks up an export while the caller holds the open reference.
- `pudu_loader_close` releases that reference and reports whether release succeeded.
- `pudu_loader_error` copies the platform error on the calling thread.

## Resolved Grill Log

Use the wide-character Windows APIs. Search approved loader directories for
bare DLL names and allow an explicitly named path to resolve its own
dependencies. POSIX uses local binding with the caller's choice of lazy or
eager resolution. Both backends use the platform's function-pointer
representation. A cached symbol requires a still-open library.

## Referenced by

[[Foreign Call Library]] · [[Native Host Foreign]] · [[Pudu SQLite Bridge]] · [[cbits/_MOC|Native Boundary Module Map]]
