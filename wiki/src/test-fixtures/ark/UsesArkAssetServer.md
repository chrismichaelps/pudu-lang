---
type: module
path: "@root/test-fixtures/ark/UsesArkAssetServer.pudu"
fidelity: Active
aliases: [Ark Asset Server Fixture]
tags: [module, ark, assets, test]
---

# Ark Asset Server Fixture

## Purpose and interface

Round-trips the cooked texture format and checks every importer refusal. Declaration failures
cover unknown importer kinds, cycles, missing sources, malformed cooked data, duplicate adds and
missing dependencies. A real temporary directory mounted through [[Ark Virtual Files]] drives a
texture, a material over it and an unrelated byte asset: dependency-first open, identity refresh,
a byte-identical rewrite that advances nothing, a changed texture that re-imports exactly the
texture and its material, an older server retaining its snapshot, a failed stage that publishes
nothing, recovery, dependent-blocked and unknown unloads, stale handles and a reused slot that
rejects the old generation. Prints `ark asset server: ok`.

## Resolved Grill Log

- **Q:** Use only memory mounts? **A:** No; hot reload exists for files changing on disk, so the
  staged reload runs against a real directory rewritten between refreshes.

## Referenced by

[[Ark Asset Server]] · [[Ark Asset Import]] · [[Ark Assets Gate]] · [[src/Ark/_MOC]]
