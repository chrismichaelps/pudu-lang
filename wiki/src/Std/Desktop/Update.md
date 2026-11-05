---
type: module
path: "@root/lib/Std/Desktop/Update.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, updates, security]
aliases: [Std Desktop Update]
---

# Std Desktop Update

## Purpose and interface

The automatic update system. `Config` names the endpoints, the trusted public keys, the release
track, the running version and platform, the installation root and a download limit. `check` finds a
newer `Release`; `parseManifest` reads one manifest; `fetchArchive` downloads and verifies it,
through a patch when one applies; `install` stages and swaps it in; `startup` and `confirm` finish or
roll back an install across restarts; `background` and `poll` run the check and download on a
worker; `manifest` writes a manifest entry for the release tooling.

## Semantics

- Endpoints are tried in order; a template may write `{{target}}`, `{{arch}}`, `{{current_version}}`
  and `{{channel}}`. Status `204` means no update; any other non-2xx moves to the next endpoint; plain
  `http` is refused except for `localhost` and `127.0.0.1`.
- A manifest is validated whole before its version is compared: every platform entry needs `url`,
  `size`, `sha256` and `signature`. Tracks are read through a const factory table and ranked
  `stable` < `beta` < `nightly`; a subscriber takes releases of its own track and every more stable
  one. Only a version strictly after the running one is an update.
- Every artifact and patch is checked for size, SHA-256 and an Ed25519 signature over its bytes by a
  trusted key; there is no switch that skips verification.
- A patch is used when it starts from the running version and the cached archive of that version
  exists; the rebuilt archive must match the patch's signed target digest. Any patch failure falls
  back to the full artifact.
- `install` unpacks into `<root>.pudu-new`, refusing entries that leave it, keeps the old tree as
  `<root>.pudu-previous`, swaps by rename, records `<root>.pudu-pending`, and caches the archive for
  the next patch. A failed swap renames the previous tree back.
- `startup` on a pending install: the first start counts the attempt; a second start without
  `confirm` restores the previous tree and answers `RolledBack`. `confirm` removes the marker and the
  previous tree.

## Grill Log

- **Q:** Why roll back on the second unconfirmed start rather than on a crash signal? **A:** A crash
  may not run any code at all; counting starts needs nothing from the failed version except that it
  never called `confirm`.
- **Q:** Why cache the uncompressed archive? **A:** Patches are computed over uncompressed archives
  ([[Std Desktop Delta]]), and recompressing to recover exact bytes would depend on the compressor's
  version.

## Dependencies and consumers

Uses [[Std Crypto Sign]], [[Std Desktop Delta]], [[Std Http Client]], [[Std Json]], [[Std Semver]],
[[Std Archive Tar]], [[Std Compress Gzip]], [[Std Fs]], [[Std Io]], [[Std Concurrent]] and
[[Std Channel]]. Consumed by applications and [[Std Desktop Cli]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
