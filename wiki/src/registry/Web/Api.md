---
type: module
path: "@root/registry/src/Web/Api.pudu"
fidelity: Active
tags: [registry, http, api]
aliases: [registry Web Api]
---
# Registry Web Api

The `/api/v1` routes of [[architecture/PACKAGES]]: search, project document, settings, delete, push (`PUT …/head`, multipart `archive` and `visibility`), release (`POST …/releases`, multipart `version`, `notes`, `archive`, `visibility`), archive and file downloads, yank, handle profile, device pairing and polling (428 while waiting, 410 expired), `whoami`, and token revocation. A private project answers 404 to anyone but its owner. Errors are `{"error": reason}`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Base64 JSON uploads? **A:** Multipart. _Rationale:_ the archive travels as its bytes. _Rejected:_ base64 in JSON.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
