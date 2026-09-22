---
type: module
path: "@root/registry/src/Domain/Version.pudu"
fidelity: Active
tags: [registry, packages, versions]
aliases: [registry Domain Version]
---
# Registry Domain Version

Release versions: `parse` (`MAJOR.MINOR.PATCH` with optional pre-release, no build metadata, no leading zeros), `render`, `compare` (pre-release before release, numeric fields as numbers, a number before a word), and `isPrerelease`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Accept build metadata? **A:** No. _Rationale:_ two archives would share one version. _Rejected:_ ignoring it.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
