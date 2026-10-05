---
type: module
path: "@root/lib/Std/Semver.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, versioning]
aliases: [Std Semver]
---
# Std Semver
## Purpose
Read, render, order, and select semantic versions.
## Interface
Exports `Version`, `VersionError`, `parse`/`render`, `of`, ordering (`before`, `same`, `after`),
`isStable`, `satisfies`, `best`, and `explain`.
## Governance and algorithm
A version is three numbers, an optional prerelease after `-`, and an optional build after `+`. Every
prerelease and build identifier is non-empty ASCII letters, digits, and `-` (`BadIdentifier`,
`EmptyIdentifier`). A leading zero is refused in the core numbers and in a prerelease identifier of
digits alone (`LeadingZero`), so no version can be written two ways. Build metadata takes no part in
ordering.
## Grill Log
- **Q:** Trim leading zeros instead of refusing them? **A:** No. _Rationale:_ a registry keyed by
  the text would hold `1.0.0-01` and `1.0.0-1` as two entries for one version. _Rejected:_
  normalising silently.
- **Q:** Accept any characters in identifiers? **A:** No. _Rationale:_ other tools refuse them, so a
  version accepted here would not survive a round trip elsewhere. _Rejected:_ permissive parsing.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
