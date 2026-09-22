---
type: module
path: "@root/registry/src/Main.pudu"
fidelity: Active
tags: [registry, cli]
aliases: [registry Main]
---
# Registry Main

`serve` with `--data`, `--host`, `--port`, `--url`, `--github-client-id` (or `REGISTRY_GITHUB_CLIENT_ID`), `--github-url`, and `--github-api`; a GitHub address on this machine is permitted by the outbound checks. `/health` answers `ok`.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Keep a command that creates accounts? **A:** No; accounts are GitHub's.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu` and `test/package-registry.py`.
