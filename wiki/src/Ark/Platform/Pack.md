---
type: module
path: "@root/lib/Ark/Platform/Pack.pudu"
fidelity: Active
aliases: [Ark Pack]
tags: [module, ark, platform, build]
---

# Ark Pack

## Purpose and interface

`encode(files)` writes one ARKP blob: magic, little-endian u32 version and count, then per file a
u32 path length, the UTF-8 path, u64 data offset, u64 length and CRC-32, then the data. Paths are
sorted, so equal inputs produce byte-identical packs. `decode(pack)` checks magic, version, index
bounds, canonical unique paths, data bounds and every checksum, and answers each file as a slice
of the pack's own bytes. `validPath` is the canonical relative-path rule shared with
[[Ark Virtual Files]].

## Resolved Grill Log

- **Q:** Copy files out of the pack on load? **A:** No; byte slices are views, so mounting a pack
  costs its index and checksums, not a second copy of its data.
- **Q:** Trust the index? **A:** No; a pack is input. Every offset, length and checksum is checked
  before a file is reachable.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Build]] · [[Ark Virtual Files]] · [[Ark Build Fixture]]
