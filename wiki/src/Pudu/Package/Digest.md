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

`sha256Hex` over bytes, `treeFiles`/`treeDigest` over a directory (sorted relative paths with `/`, each line `path NUL size NUL sha256 LF`, digest `sha256:<hex>`), and `copyTree`. Dot entries and a package's own top-level `deps/` are not content; a symbolic link is refused rather than followed.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Include modification times or modes? **A:** No. _Rationale:_ the digest must be the same on every machine for the same files. _Rejected:_ archive-of-the-directory hashing.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
