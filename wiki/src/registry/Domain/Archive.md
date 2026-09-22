---
type: module
path: "@root/registry/src/Domain/Archive.pudu"
fidelity: Active
tags: [registry, packages, archives, security]
aliases: [registry Domain Archive]
---
# Registry Domain Archive

`unpack` reads a canonical package archive; `fromCommitArchive` reads GitHub's commit archive, removes its top directory, refuses links and other entry types, unsafe paths (before any filtering), duplicates, and archives past `UNPACKED_LIMIT` or `FILE_LIMIT`, and leaves out paths with a segment starting with `.` and a top-level `deps/`; `pack` writes the canonical `.tar.gz` (sorted, mode 0644, fixed time). `fileAt`, `modulesUnder`, `totalSize`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Filter dot paths before checking for `..`? **A:** Check first. _Rationale:_ `..` starts with a dot, and filtering first dropped a traversal silently instead of refusing it.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu` and `test/package-registry.py`.
