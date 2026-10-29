---
type: module
path: "@root/test-fixtures/ark/UsesArkBuild.pudu"
fidelity: Active
aliases: [Ark Build Fixture]
tags: [module, ark, build, test]
---

# Ark Build Fixture

## Purpose and interface

Round-trips packs, including empty ones, and checks byte-identical output for differently
ordered inputs. Refuses bad magic, an unknown version, a truncated index, flipped data
(checksum), short data (bounds), noncanonical paths and a hand-built duplicate entry. Mounts a
pack and reads through it; a corrupt pack fails at mount. Cooks a texture, a material over it and
raw bytes from a memory mount, loads the pack into a server with dependency order and payloads
intact, and refuses bad data, the reserved manifest name and non-pack input. Prints
`ark build: ok`.

## Resolved Grill Log

- **Q:** Check corruption only through decode? **A:** No; the same corruption is also refused at
  `mountPack`, the path a game actually uses.

## Referenced by

[[Ark Build]] · [[Ark Pack]] · [[Ark Build Gate]] · [[src/Ark/_MOC]]
