---
type: module
path: "@root/registry/src/Domain/Project.pudu"
fidelity: Active
tags: [registry, packages, documents]
aliases: [registry Domain Project]
---
# Registry Domain Project

The project document: `Release` (immutable: version, time, publisher, checksum, size, language, dependencies, modules, notes, yanked), `Head` (latest pushed snapshot), and `Project`. `latest` is the last non-yanked release in version order; `toJson`/`fromJson` read and write the stored document, `summaryJson` the search form.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Store the uploader's claimed metadata? **A:** No; version, dependencies, root, and modules come from the archive's own `pudu.toml` and files. _Rationale:_ manifest confusion. _Rejected:_ request fields.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
