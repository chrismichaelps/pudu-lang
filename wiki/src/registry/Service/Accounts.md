---
type: module
path: "@root/registry/src/Service/Accounts.pudu"
fidelity: Active
tags: [registry, accounts]
aliases: [registry Service Accounts]
---
# Registry Service Accounts

`signUp` (valid, unreserved, unused handle; password of at least `PASSWORD_MINIMUM` characters stored by `Std.App.Password`) and `signIn`, which gives the same refusal for an unknown handle and a wrong password.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Say which of handle or password was wrong? **A:** No. _Rationale:_ it confirms which handles exist. _Rejected:_ separate messages.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
