---
type: module
path: "@root/registry/src/Store/Files.pudu"
fidelity: Active
tags: [registry, storage]
aliases: [registry Store Files]
---
# Registry Store Files

The on-disk layout under one data directory (accounts, projects, release archives and files, head snapshots, token index, device pairings) and its primitives: `ensureDirectory`, `writeJson` and `writeBytes` (atomic rename), `readJson`, `removeTree`, `children`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** A database? **A:** Files. _Rationale:_ release documents and archives are immutable and servable by any static host. _Rejected:_ SQLite for phase 2.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
