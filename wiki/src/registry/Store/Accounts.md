---
type: module
path: "@root/registry/src/Store/Accounts.pudu"
fidelity: Active
tags: [registry, storage, accounts]
aliases: [registry Store Accounts]
---
# Registry Store Accounts

`Account` (handle, display name, stored password digest, second-factor fields, tokens) and `Token` (digest, access, label, time). `load`/`save`/`handles`, and the token index: `indexToken`, `tokenOwner`, `unindexToken` over `tokens/<digest>.json`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Find a token by scanning accounts? **A:** No, by its digest's index file. _Rationale:_ one read per request. _Rejected:_ a scan.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
