---
type: module
path: "@root/registry/src/Web/Api.pudu"
fidelity: Active
tags: [registry, http, api]
aliases: [registry Web Api]
---
# Registry Web Api

The `/api/v1` routes of [[architecture/PACKAGES]]: search, project document, settings, delete, push (`PUT …/head`), release (`POST …/releases` with `{version, tag, notes}`), archive and file downloads, yank, handle profile, `config` (the GitHub client id and addresses for `pudu login`), and `whoami`. A private project answers 404 to any token that cannot read its repository. A listed release whose file tree cannot be read answers 500 rather than a misleading empty file list. Errors are `{"error": reason}`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Upload archives from the client? **A:** No; the registry fetches the tagged commit from GitHub. _Rationale:_ a release is then exactly what is on GitHub. _Rejected:_ multipart uploads.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu` and `test/package-registry.py`.
