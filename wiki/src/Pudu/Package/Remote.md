---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Remote.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, registry, cache]
aliases: [Package Remote]
---

# Package Remote

## Purpose and interface

`remoteRegistry` answers `Solve.Registry` from `/api/v1`. Project documents are cached per registry; a package whose locked version is in its cached document is answered without a request (packages being updated always ask). Each document is read once per run. Archives are cached by digest and unpacked once; a cached archive with the wrong digest is downloaded again, a downloaded one is refused before unpacking, and an unpacked `pudu.toml` naming another package or version is refused before the directory takes its cache name. `registryUrlFor` (`PUDU_REGISTRY`, `[install] registry`, default `https://packages.pudu-lang.org`), `minimumAgeFor` (`PUDU_MIN_RELEASE_AGE`, `[install] min-release-age`, default 72 hours) marks recent releases. An unknown name reports up to three close matches from search.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Ask the registry on every install? **A:** Not when the cache holds the locked version. _Rationale:_ a lock and a warm cache make no request. _Rejected:_ revalidating each time.
- **Q:** Trust a cached archive? **A:** Re-hash it and download again on mismatch. _Rationale:_ the cache is shared and may be damaged; the registry's bytes are what the lock proves.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs` and `test/package-registry.py`.
