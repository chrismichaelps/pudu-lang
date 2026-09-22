---
type: module
path: "@root/registry/src/Store/Profiles.pudu"
fidelity: Active
tags: [registry, storage, github]
aliases: [registry Store Profiles]
---
# Registry Store Profiles

`profiles/<login>.json`: a handle's display name, avatar, GitHub address, and kind, copied from GitHub when a project is registered or released. `load`, `save`, `toJson`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Ask GitHub for a profile on every page? **A:** Copy it at publish time. _Rationale:_ pages and the website snapshot must not depend on GitHub's rate limits.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu` and `test/package-registry.py`.
