---
type: module
path: "@root/registry/src/Domain/Manifest.pudu"
fidelity: Active
tags: [registry, packages, manifest]
aliases: [registry Domain Manifest]
---
# Registry Domain Manifest

`read(text, release)` reads the `pudu.toml` inside an uploaded archive: the name must be `@handle/name`, the root valid, and every dependency a registry requirement (a path or git dependency is refused). With `release` the version is required and must parse; a push may omit it.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Allow git or path dependencies in a release? **A:** No. _Rationale:_ a release must resolve from the registry alone. _Rejected:_ publishing machine-local paths.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
