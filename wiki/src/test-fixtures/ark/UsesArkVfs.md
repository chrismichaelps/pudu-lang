---
type: module
path: "@root/test-fixtures/ark/UsesArkVfs.pudu"
fidelity: Active
aliases: [Ark Vfs Fixture]
tags: [module, ark, platform, test]
---

# Ark Vfs Fixture

## Purpose and interface

Exercise memory and directory mounts, stable byte reads, duplicate/unknown mounts, unmounting and
immutable memory snapshots. Reject bad names and relative paths, traversal, malformed virtual URIs,
fabricated backends and missing resources. A temporary directory verifies disk bytes, refusal of
a file as a mount root and canonical symlink-escape rejection. Read RGBA bytes through the virtual
resource boundary and construct/sample an [[Ark Texture Asset]] end to end. Successful execution
prints `ark vfs: ok`; filesystem setup is scoped through `Fs.withTemporaryDirectory`.

## Resolved Grill Log

- **Q:** Mock filesystem behavior only? **A:** No; create real scoped resources and a link outside
  the mounted directory, while keeping pure memory-mount cases independent.

## Referenced by

[[Ark Virtual Files]] · [[Ark Platform Gate]] · [[src/Ark/_MOC]]
