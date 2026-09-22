---
type: module
path: "@root/registry/src/Domain/Project.pudu"
fidelity: Active
tags: [registry, packages, documents]
aliases: [registry Domain Project]
---
# Registry Domain Project

The project document: `Release` (version, time, publisher, checksum, size, language, dependencies, modules, notes, yanked, tag, commit), `Head`, and `Project` (with its repository address). `latest` is the last non-yanked release in version order; `toJson`/`fromJson`/`summaryJson`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Record where a release came from? **A:** Its tag and commit. _Rationale:_ a reader can compare the release with the repository at that commit.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu` and `test/package-registry.py`.
