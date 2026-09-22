---
type: module
path: "@root/registry/src/Domain/Archive.pudu"
fidelity: Active
tags: [registry, packages, archives, security]
aliases: [registry Domain Archive]
---
# Registry Domain Archive

`unpack` gunzips within `UNPACKED_LIMIT` (64 MiB), reads the tar stream, and refuses symbolic links and any other non-file entry, absolute paths, `.`/`..`/empty segments, backslashes and NUL, duplicate paths, paths over 255 bytes, and more than `FILE_LIMIT` (5000) files; files are returned sorted. `fileAt`, `modulesUnder` (module names of `.pudu` files under the source directory), and `totalSize`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Refuse or skip a symbolic link? **A:** Refuse the archive. _Rationale:_ a package holds only files and directories, and a silently dropped entry changes what was published. _Rejected:_ skipping.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
