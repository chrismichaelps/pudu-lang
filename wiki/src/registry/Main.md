---
type: module
path: "@root/registry/src/Main.pudu"
fidelity: Active
tags: [registry, cli]
aliases: [registry Main]
---
# Registry Main

`serve` (`--data`, `--host`, `--port`, `--url`), `account --handle --password` (creates an account and prints a publish token), and `token --handle [--scope]`. Uploads up to `Api.UPLOAD_LIMIT` (16 MiB) are accepted; `/health` answers `ok`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Create accounts from the command line? **A:** Yes, for operators and CI. _Rationale:_ a fresh registry needs a first account without a browser. _Rejected:_ web-only sign-up.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
