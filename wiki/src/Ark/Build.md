---
type: module
path: "@root/lib/Ark/Build.pudu"
fidelity: Active
aliases: [Ark Build]
tags: [module, ark, build]
---

# Ark Build

## Purpose and interface

`cook(vfs, sources)` opens an [[Ark Asset Server]] over the declarations, so every asset is read
and imported exactly as the runtime will, then packs each asset's source bytes under its ID with
`manifest.arkm` (one `id`, importer and comma-separated dependencies per line) through
[[Ark Pack]]. `load(vfs, mount, pack)` mounts the pack, reads the manifest and opens an asset
server whose sources point into the pack. IDs that are not canonical paths, contain manifest
separators or claim the manifest's name are refused.

## Resolved Grill Log

- **Q:** Copy files into the pack without importing them? **A:** No; cooking is where broken
  content must fail, before it ships.
- **Q:** Keep authoring paths in the shipped manifest? **A:** No; packed assets are addressed by
  ID inside the pack mount, so the shipped layout does not leak authoring directories.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Build Fixture]] · [[Ark Build Gate]]
