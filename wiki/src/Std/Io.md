---
type: module
path: "@root/lib/Std/Io.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, io]
aliases: [Std Io]
---
# Std Io
## Purpose
Provide total console, file, directory, and portable path operations over prelude effects.
## Interface
Exports line/value IO, file read/write/append/remove/list/copy/move operations, and path separator/join/name/extension helpers.
## Governance and algorithm
Host failures remain `Result[_, Str]`; path logic asks the runtime for separators and recognizes every returned separator instead of hard-coding one platform.

Streaming readers hold one 64 KiB chunk at a time. `foldLines` looks for the last newline in each new chunk only; a chunk without one is kept as a pending piece, and a chunk with one closes a block that is joined once, decoded once, and divided by one native split. A line longer than a chunk is therefore joined once rather than rescanned per chunk, and the interpreted work per line is the caller's step alone. Cutting at a newline byte never divides an encoded character, so a block that fails to decode is text that is not valid, reported as `NotText`.
## Grill Log
- **Q:** Why keep path operations here? **A:** Their portable separator contract belongs beside the effects that obtain host paths. _Rejected:_ slash-only helpers.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
