---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Digest.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, integrity]
aliases: [Package Digest]
---

# Package Digest

## Purpose and interface

`sha256Hex` over bytes, `treeFiles`/`treeDigest` over a directory (sorted relative paths with `/`, each line `path NUL size NUL sha256 LF`, digest `sha256:<hex>`), `copyTree` (answers the tree digest of the bytes it wrote, so a copy is hashed once), `treeFingerprint` (a digest of each file's path, size, and modification time, read without opening files), and `cachedTreeDigest` (the digest of a directory never written again, kept in `<directory>.digest`). Dot entries and a package's own top-level `deps/` are not content; a symbolic link is refused rather than followed.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Include modification times or modes? **A:** No. _Rationale:_ the digest must be the same on every machine for the same files. _Rejected:_ archive-of-the-directory hashing.
- **Q:** Hash `deps/` on every install? **A:** Only when its fingerprint changed. _Rationale:_ a second install of unchanged code should cost a directory walk; a touched but identical file is settled by hashing and kept. _Rejected:_ trusting presence, and hashing every time.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
