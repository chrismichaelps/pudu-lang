---
type: module
path: "@root/registry/src/Service/Publish.pudu"
fidelity: Active
tags: [registry, publishing]
aliases: [registry Service Publish]
---
# Registry Service Publish

`push` stores a head snapshot; `release` stores an immutable release after checking the token, that the manifest names the routed package, that its version is the one asked for, that the version is new, and that it is not lower than a release on the same major line; `checksumOf` is `sha256:<hex>` of the archive bytes. A new project named one edit from another handle's released project is refused. `yank`, `configure` (description, visibility), and `remove` (delete when there are no releases, otherwise unlist). Refusals carry an HTTP status.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Delete a released project? **A:** Unlist it. _Rationale:_ existing locks must keep installing. _Rejected:_ deletion.
- **Q:** Refuse look-alike names? **A:** Against projects another handle has released. _Rationale:_ typosquatting targets established names. _Rejected:_ refusing against every name.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
