---
type: module
path: "@root/registry/src/Service/Auth.pudu"
fidelity: Active
tags: [registry, security, github]
aliases: [registry Service Auth]
---
# Registry Service Auth

`viewerOf` reads `Authorization: Bearer`, asks GitHub whose token it is, and remembers the answer by the token's SHA-256 for `REMEMBER_MILLIS` (five minutes); the token itself is never written. `tokenOf`, `tokenFor`, and `repositoryFor` (the repository as the viewer's token sees it).

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Issue registry tokens? **A:** No; accept GitHub's. _Rationale:_ nothing secret is stored, and revoking on GitHub revokes here. _Rejected:_ a registry token exchanged for a GitHub one.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu` and `test/package-registry.py`.
