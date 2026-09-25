---
type: module
path: "@root/test/Pudu/VersionSpec.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, bundle]
aliases: [Version Spec]
---

# Version Spec

## Purpose and interface

`versionProperties` checks the source digest: sixty-four hex digits, the identity naming version
and digest, and `digestIn` finding a literal inside other bytes, skipping a bare prefix for a
later literal, and refusing a short digest, capitals, a missing terminator, and bytes with none.

## Referenced by

[[Pudu Version]] · [[Version Digest]]
