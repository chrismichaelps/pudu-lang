---
type: module
path: "@root/registry/src/Store/Projects.pudu"
fidelity: Active
tags: [registry, storage]
aliases: [registry Store Projects]
---
# Registry Store Projects

`load`/`save` of `project.json`, `ofHandle`, and `all`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Keep an index of projects? **A:** Not yet; listing directories is enough at this size. _Rejected:_ a second source of truth.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
