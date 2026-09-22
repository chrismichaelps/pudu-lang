---
type: module
path: "@root/registry/src/Web/Pages.pudu"
fidelity: Active
tags: [registry, http, html]
aliases: [registry Web Pages]
---
# Registry Web Pages

HTML forms for `/signup` and `/login/device` (code prefilled from `?code=`), escaping every value.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Approve a device without a password? **A:** No. _Rationale:_ the code alone is visible on the terminal that asked. _Rejected:_ one-click approval.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
