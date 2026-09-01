---
type: module
path: "@root/lib/Std/Path.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, path]
aliases: [Std Path]
---
# Std Path
## Purpose
Construct and decompose lexical paths using the host's separators without touching the filesystem.
## Interface
Exports join, normalization, components, names/extensions, parents/ancestors, absolute/relative
classification, containment, and relative-path derivation.
## Governance and algorithm
All answers are lexical: links are not followed and paths need not exist. The runtime supplies the
separator set so foreign path spellings can be recognized without hard-coding one platform.
## Grill Log
- **Q:** Resolve paths against the filesystem? **A:** No. _Rationale:_ that would add IO, races, and
  link semantics to otherwise deterministic functions. _Rejected:_ slash-only parsing.
## Referenced by
[[src/Std/_MOC]] · [[Std Io]] · [[architecture/STDLIB]]
