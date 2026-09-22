---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Archive.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, archives, security]
aliases: [Package Archive]
---

# Package Archive

## Purpose and interface

`packDirectory` writes the files `Digest.treeFiles` lists as USTAR (mode 0644, owner 0, time 0, sorted; long paths through the prefix field) and gzips at level 9, so the same files give the same bytes. `archiveEntries` decompresses within `unpackedLimit` (64 MiB) and refuses hard and symbolic links and other entry types, absolute paths, empty/`.`/`..` segments, backslashes and NUL, paths over 255 bytes, duplicates, and more than `fileLimit` (5000) files. `unpackArchive` writes through a staging directory renamed into place.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Keep modification times? **A:** No, time 0. _Rationale:_ the archive digest must depend only on the files. _Rejected:_ real times.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs` and `test/package-registry.py`.
