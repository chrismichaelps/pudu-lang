---
type: module
path: "@root/lib/Ark/Platform/Vfs.pudu"
fidelity: Active
aliases: [Ark Virtual Files]
tags: [module, ark, platform, resources]
---

# Ark Virtual Files

## Purpose and interface

Immutable virtual resource mounts keep host file access inside Platform. `empty`,
`mountDirectory(vfs, name, root)`, `mountMemory(vfs, name, files)` and `unmount` manage named roots.
`read(vfs, "name:/relative/path") -> Result[Bytes, ResourceError]` returns owned immutable bytes.
Directory mounts canonicalize an existing directory and use [[Std Fs]] real-location containment
before [[Std Io]] scoped byte reads. Memory mounts hold validated relative-name/byte maps; old
Vfs values retain their memory snapshots. A const reader table selects directory/memory backends.

Names are nonempty and exclude slash, backslash, colon, NUL and dot-directory names. Relative
paths use forward slashes with nonempty components, no `.`/`..`, backslash, colon or NUL. Reject
noncanonical spellings instead of silently aliasing resource identities.
Mount names are case-sensitive logical names; physical directory lookup retains the host's
case/link behavior, so contained symlink aliases may share bytes under different virtual names.
Duplicate mount names, unknown mounts/backends, bad paths and missing memory entries have explicit error variants;
filesystem and read failures preserve their typed lower-layer causes. Reads revalidate virtual
paths, backend kinds and nonempty/NUL-free directory roots even for fabricated records, without
rescanning unreachable memory-map keys. `unmount` returns None for an unknown name.

Directory roots are trusted game resource roots. Canonical containment rejects symlink escapes
present during resolution; this API does not lock filesystem components against concurrent
replacement. No adversarial filesystem sandbox or atomic open-relative guarantee is claimed.
The API owns no persistent file handles; each scoped read closes before it returns.

## Resolved Grill Log

- **Q:** Let Assets import host I/O for every format? **A:** No; Assets consumes virtual bytes
  through Platform, keeping filesystem variability at one layer boundary.
- **Q:** Normalize traversal into a different asset identity? **A:** No; reject noncanonical
  paths and keep authored virtual resource identity stable.
- **Q:** Choose storage kinds with branching ladders? **A:** No; dispatch through a const
  reader table, retaining typed errors for unsupported fabricated records.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Vfs Fixture]] · [[Ark Platform Gate]] · [[Ark Vfs Delivery]]
