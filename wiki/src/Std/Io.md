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
## Grill Log
- **Q:** Why keep path operations here? **A:** Their portable separator contract belongs beside the effects that obtain host paths. _Rejected:_ slash-only helpers.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
