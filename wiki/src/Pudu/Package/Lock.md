---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Lock.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, lockfile]
aliases: [Package Lock]
---

# Package Lock

## Purpose and interface

`pudu.lock`: `version = 1` and one `[[package]]` per locked package with `name`, `version`, `source`, `checksum`, `root`, `dependencies` (names). `renderLock` sorts entries and fixes field order so the same graph writes the same bytes; `parseLock` accepts exactly that and names the line it cannot read.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Parse general TOML? **A:** No. _Rationale:_ a lock is written by the tool; accepting more than it writes accepts hand edits and half-merged files silently. _Rejected:_ a full TOML reader.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
