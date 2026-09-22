---
type: module
path: "@root/registry/src/Service/Tokens.pudu"
fidelity: Active
tags: [registry, security, tokens]
aliases: [registry Service Tokens]
---
# Registry Service Tokens

`newSecret` (`pudu_` + 64 hex digits from the secure source), `digestOf` (SHA-256), `issue`, `revoke`, `viewerOf` (from an `Authorization: Bearer` header), `mayPublish` (own handle and `publish` access), and `mayRead` (own handle). Only digests are stored.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Store token secrets? **A:** Digests only. _Rationale:_ a copy of the store must not publish. _Rejected:_ encrypted secrets.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
