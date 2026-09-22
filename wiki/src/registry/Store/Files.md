---
type: module
path: "@root/registry/src/Store/Files.pudu"
fidelity: Active
tags: [registry, storage]
aliases: [registry Store Files]
---
# Registry Store Files

The layout under one data directory — projects (documents, release archives and files, head snapshots), `profiles/`, and `cache/viewers/` — and its primitives: `ensureDirectory`, `writeJson`, `writeBytes` (atomic rename), `readJson`, `removeTree`, `children`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** A database? **A:** Files. _Rationale:_ release documents and archives are immutable and servable by any static host.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu` and `test/package-registry.py`.
